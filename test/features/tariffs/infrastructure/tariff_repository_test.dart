import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_local_data_source.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_remote_data_source.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements TariffRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  int deleteCalls = 0;

  @override
  Future<List<Tariff>> list(String token) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [
      Tariff(id: 1, categoryId: 1, type: TariffType.hourly, amount: 3000),
    ];
  }

  @override
  Future<Tariff> create(String token, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<Tariff> update(String token, int id, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String token, int id) async {
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
    tempDir = await Directory.systemTemp.createTemp('tariff_repo_test');
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

  TariffRepositoryImpl repository(_FakeRemote remote) => TariffRepositoryImpl(
        auth,
        remote,
        HiveTariffLocalDataSource(),
      );

  test('list returns remote tariffs and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.amount, 3000);
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveTariffLocalDataSource();
    await TariffRepositoryImpl(auth, _FakeRemote(), local).list();

    final offline = TariffRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
    );

    expect((await offline.list()).single.amount, 3000);
  });

  test('delete calls the remote data source', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);

    await repo.delete(1);

    expect(remote.deleteCalls, 1);
  });
}
