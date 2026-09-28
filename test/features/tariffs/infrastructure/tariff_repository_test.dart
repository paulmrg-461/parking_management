import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_local_data_source.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_remote_data_source.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_repository_impl.dart';

import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements TariffRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  int deleteCalls = 0;

  @override
  Future<List<Tariff>> list() async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [
      Tariff(id: 1, categoryId: 1, type: TariffType.hourly, amount: 3000),
    ];
  }

  @override
  Future<Tariff> create(Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<Tariff> update(int id, Map<String, dynamic> payload) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return Tariff(
      id: id,
      categoryId: 1,
      type: payload['type'] != null
          ? TariffType.values.byName(payload['type'] as String)
          : TariffType.hourly,
      amount: payload['amount'] as int? ?? 3000,
    );
  }

  @override
  Future<void> delete(int id) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    deleteCalls++;
  }
}

void main() {
  late Directory tempDir;
  late FakeSyncOutbox outbox;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tariff_repo_test');
    Hive.init(tempDir.path);
    outbox = FakeSyncOutbox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  TariffRepositoryImpl repository(_FakeRemote remote) =>
      TariffRepositoryImpl(remote, HiveTariffLocalDataSource(), outbox);

  test('list returns remote tariffs and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.amount, 3000);
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveTariffLocalDataSource();
    await TariffRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = TariffRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.list()).single.amount, 3000);
  });

  test('delete calls the remote data source', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);

    await repo.delete(1);

    expect(remote.deleteCalls, 1);
  });

  test('update queues the mutation and returns an optimistic result on network failure', () async {
    final local = HiveTariffLocalDataSource();
    await TariffRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = TariffRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    final result = await offline.update(
      const UpdateTariffCommand(id: 1, amount: 5000),
    );

    expect(result.id, 1);
    expect(result.amount, 5000);
    expect(result.type, TariffType.hourly);
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.tariff);
    expect(outbox.enqueued.single.operation, MutationOperation.update);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test('delete removes the local cache entry and queues the mutation on network failure', () async {
    final local = HiveTariffLocalDataSource();
    await TariffRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = TariffRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await offline.delete(1);

    expect(await local.readAll(), isEmpty);
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.tariff);
    expect(outbox.enqueued.single.operation, MutationOperation.delete);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test(
    'Failure: offline update of an uncached tariff rethrows and queues nothing',
    () async {
      final offline = TariffRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        HiveTariffLocalDataSource(),
        outbox,
      );

      await expectLater(
        offline.update(const UpdateTariffCommand(id: 99, amount: 5000)),
        throwsA(isA<NetworkFailure>()),
      );
      expect(outbox.enqueued, isEmpty);
    },
  );

  test(
    'Security: offline update never invents categoryId 0 in the cache',
    () async {
      final local = HiveTariffLocalDataSource();
      final offline = TariffRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      await expectLater(
        offline.update(const UpdateTariffCommand(id: 99, active: false)),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await local.readAll(), isEmpty);
    },
  );
}
