import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/infrastructure/category_local_data_source.dart';
import 'package:parking_management/features/categories/infrastructure/category_remote_data_source.dart';
import 'package:parking_management/features/categories/infrastructure/category_repository_impl.dart';

import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements CategoryRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  VersionConflictFailure? conflict;
  int? sentBaseVersion;
  Map<String, dynamic>? sentPayload;

  @override
  Future<List<Category>> list() async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [Category(id: 1, name: 'carro', capacity: 5, version: 2)];
  }

  @override
  Future<Category> create(String name) async => Category(id: 2, name: name);

  @override
  Future<Category> setCapacity(int id, int capacity, {int? baseVersion}) =>
      patch(id, {'capacity': capacity}, baseVersion: baseVersion);

  @override
  Future<Category> update(int id, String name, {int? baseVersion}) =>
      patch(id, {'name': name}, baseVersion: baseVersion);

  @override
  Future<Category> patch(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  }) async {
    sentBaseVersion = baseVersion;
    sentPayload = payload;
    final error = conflict;
    if (error != null) {
      throw error;
    }
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return Category(
      id: id,
      name: payload['name'] as String? ?? 'x',
      capacity: payload['capacity'] as int? ?? 0,
    );
  }

  @override
  Future<void> delete(int id, {int? baseVersion}) async {
    sentBaseVersion = baseVersion;
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
  }
}

void main() {
  late Directory tempDir;
  late FakeSyncOutbox outbox;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('category_repo_test');
    Hive.init(tempDir.path);
    outbox = FakeSyncOutbox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  CategoryRepositoryImpl repository(_FakeRemote remote) =>
      CategoryRepositoryImpl(
        remote,
        HiveCategoryLocalDataSource(LotSession()),
        outbox,
      );

  test('list returns remote categories and caches them', () async {
    final repo = repository(_FakeRemote());

    final result = await repo.list();

    expect(result.single.name, 'carro');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveCategoryLocalDataSource(LotSession());
    await CategoryRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = CategoryRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.list()).single.name, 'carro');
  });

  test('create calls the remote data source', () async {
    final repo = repository(_FakeRemote());

    final created = await repo.create('bus');

    expect(created.name, 'bus');
    expect(created.id, 2);
  });

  test('update queues the mutation and returns an optimistic result on network failure', () async {
    final local = HiveCategoryLocalDataSource(LotSession());
    await CategoryRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = CategoryRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    final result = await offline.update(1, 'camioneta');

    expect(result.id, 1);
    expect(result.name, 'camioneta');
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.category);
    expect(outbox.enqueued.single.operation, MutationOperation.update);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test('delete removes the local cache entry and queues the mutation on network failure', () async {
    final local = HiveCategoryLocalDataSource(LotSession());
    await CategoryRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = CategoryRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await offline.delete(1);

    expect(await local.readAll(), isEmpty);
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.category);
    expect(outbox.enqueued.single.operation, MutationOperation.delete);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test('Success: an edit sends the cached version', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);
    await repo.list();

    await repo.update(1, 'camioneta');

    expect(remote.sentBaseVersion, 2);
    expect(remote.sentPayload, {'name': 'camioneta'});
  });

  test('Success: an editor base version wins over the cache', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);
    await repo.list();

    await repo.setCapacity(1, 9, baseVersion: 7);

    expect(remote.sentBaseVersion, 7);
  });

  test('Failure: an online conflict is parked with the server row', () async {
    final repo = repository(_FakeRemote());
    await repo.list();
    final remote = _FakeRemote()
      ..conflict = VersionConflictFailure({
        'id': 1,
        'name': 'camioneta',
        'capacity': 8,
        'version': 6,
      });
    final conflicting = repository(remote);

    await expectLater(
      conflicting.update(1, 'camioneta'),
      throwsA(isA<VersionConflictFailure>()),
    );

    final parked = (await outbox.listConflicts()).single;
    expect(parked.value.entityId, 1);
    expect(parked.value.decodeServerRow()?['version'], 6);
  });

  test('Security: a pending conflict blocks further edits', () async {
    await outbox.enqueue(
      PendingMutation(
        entityType: MutationEntity.category,
        operation: MutationOperation.update,
        entityId: 1,
        payloadJson: '{"name":"bus"}',
        enqueuedAt: DateTime.utc(2026, 1, 1),
      ).asConflict(kind: 'edited', serverRow: {'id': 1, 'version': 3}),
    );
    final remote = _FakeRemote();
    final repo = repository(remote);

    await expectLater(
      repo.update(1, 'otro'),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          ClientFailureCodes.conflictPending,
        ),
      ),
    );
    expect(remote.sentBaseVersion, isNull);
  });

  test('Success: an offline edit queues the base and the whole row', () async {
    final local = HiveCategoryLocalDataSource(LotSession());
    await CategoryRepositoryImpl(_FakeRemote(), local, outbox).list();
    final offline = CategoryRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await offline.setCapacity(1, 12);

    final queued = outbox.enqueued.single;
    expect(queued.baseVersion, 2);
    expect(jsonDecode(queued.payloadJson!), {'name': 'carro', 'capacity': 12});
    expect(jsonDecode(queued.baseSnapshotJson!)['version'], 2);
  });
}
