import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_local_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_remote_data_source.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/monthly_pass_repository_impl.dart';

class _FakeRemote implements MonthlyPassRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  int deleteCalls = 0;

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
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
  Future<MonthlyPass> create(Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyPass> update(int id, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('monthly_pass_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  MonthlyPassRepositoryImpl repository(_FakeRemote remote) =>
      MonthlyPassRepositoryImpl(remote, HiveMonthlyPassLocalDataSource());

  test('Success: list returns remote monthly passes and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.amount, 100000);
  });

  test(
    'Failure: list falls back to the local cache on network failure',
    () async {
      final local = HiveMonthlyPassLocalDataSource();
      await MonthlyPassRepositoryImpl(_FakeRemote(), local).list();

      final offline = MonthlyPassRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
      );

      expect((await offline.list()).single.amount, 100000);
    },
  );

  test('Security: list with no cached data and no network returns empty, never throws', () async {
    final repo = MonthlyPassRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      HiveMonthlyPassLocalDataSource(),
    );

    expect(await repo.list(), isEmpty);
  });

  test('delete calls the remote data source', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);

    await repo.delete(1);

    expect(remote.deleteCalls, 1);
  });
}
