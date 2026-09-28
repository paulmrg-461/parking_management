import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  @override
  Future<List<Category>> list() async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [Category(id: 1, name: 'carro')];
  }

  @override
  Future<Category> create(String name) async => Category(id: 2, name: name);

  @override
  Future<Category> update(int id, String name) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return Category(id: id, name: name);
  }

  @override
  Future<void> delete(int id) async {
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
      CategoryRepositoryImpl(remote, HiveCategoryLocalDataSource(), outbox);

  test('list returns remote categories and caches them', () async {
    final repo = repository(_FakeRemote());

    final result = await repo.list();

    expect(result.single.name, 'carro');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveCategoryLocalDataSource();
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
    final local = HiveCategoryLocalDataSource();
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
    final local = HiveCategoryLocalDataSource();
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
}
