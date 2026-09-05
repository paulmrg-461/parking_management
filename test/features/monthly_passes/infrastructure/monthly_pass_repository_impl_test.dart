import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_remote_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements MonthlyPassRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  int deleteCalls = 0;
  String? tokenUsed;

  @override
  Future<List<MonthlyPass>> list(String token, {int? vehicleId}) async {
    tokenUsed = token;
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return [
      MonthlyPass(
        id: 1,
        vehicleId: 1,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        amount: 100000,
      ),
    ];
  }

  @override
  Future<MonthlyPass> create(String token, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyPass> update(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String token, int id) async {
    tokenUsed = token;
    deleteCalls++;
  }
}

void main() {
  late Directory tempDir;
  late FakeAuthRepository auth;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monthly_pass_repo_test');
    Hive.init(tempDir.path);
    auth = FakeAuthRepository(
      sessionToRestore: const AuthSession(
        user: User(id: 1, username: 'admin', displayName: 'Admin', role: UserRole.admin),
        token: 'token-1',
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  MonthlyPassRepositoryImpl repository(_FakeRemote remote) =>
      MonthlyPassRepositoryImpl(
        auth,
        remote,
        HiveMonthlyPassLocalDataSource(),
      );

  test('Success: list returns remote monthly passes and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.amount, 100000);
  });

  test('Failure: list falls back to the local cache on network failure', () async {
    final local = HiveMonthlyPassLocalDataSource();
    await MonthlyPassRepositoryImpl(auth, _FakeRemote(), local).list();

    final offline = MonthlyPassRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
    );

    expect((await offline.list()).single.amount, 100000);
  });

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final noSessionAuth = FakeAuthRepository();
      final remote = _FakeRemote();
      final repo = MonthlyPassRepositoryImpl(
        noSessionAuth,
        remote,
        HiveMonthlyPassLocalDataSource(),
      );

      expect(() => repo.list(), throwsA(isA<AuthenticationFailure>()));
      expect(remote.tokenUsed, isNull);
    },
  );

  test('delete calls the remote data source', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);

    await repo.delete(1);

    expect(remote.deleteCalls, 1);
  });
}
