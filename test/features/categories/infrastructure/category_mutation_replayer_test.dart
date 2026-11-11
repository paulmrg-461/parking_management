import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/infrastructure/category_local_data_source.dart';
import 'package:parking_management/features/categories/infrastructure/category_mutation_replayer.dart';
import 'package:parking_management/features/categories/infrastructure/category_remote_data_source.dart';

class _FakeRemote implements CategoryRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  String? updatedName;
  int? deletedId;
  Map<String, dynamic>? patched;
  int? sentBaseVersion;

  @override
  Future<Category> setCapacity(
    int id,
    int capacity, {
    int? baseVersion,
  }) async => Category(id: id, name: 'x', capacity: capacity);

  @override
  Future<Category> update(int id, String name, {int? baseVersion}) async =>
      patch(id, {'name': name}, baseVersion: baseVersion);

  @override
  Future<Category> patch(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  }) async {
    if (error != null) {
      throw error!;
    }
    patched = payload;
    sentBaseVersion = baseVersion;
    updatedName = payload['name'] as String?;
    return Category(
      id: id,
      name: payload['name'] as String? ?? 'x',
      capacity: payload['capacity'] as int? ?? 0,
    );
  }

  @override
  Future<void> delete(int id, {int? baseVersion}) async {
    sentBaseVersion = baseVersion;
    deletedId = id;
  }

  @override
  Future<Category> create(String name) async => throw UnimplementedError();

  @override
  Future<List<Category>> list() async => const [];
}

class _FakeLocal implements CategoryLocalDataSource {
  final List<Category> upserted = [];

  @override
  Future<void> upsert(Category category) async => upserted.add(category);

  @override
  Future<void> cacheAll(List<Category> categories) async {}

  @override
  Future<List<Category>> readAll() async => const [];

  @override
  Future<void> remove(int id) async {}
}

PendingMutation _mutation(
  MutationOperation op,
  String? payload, {
  int? baseVersion,
}) => PendingMutation(
  entityType: MutationEntity.category,
  operation: op,
  entityId: 2,
  payloadJson: payload,
  enqueuedAt: DateTime.utc(2026, 1, 1),
  baseVersion: baseVersion,
);

void main() {
  test('Success: update replays the rename and refreshes the cache', () async {
    final remote = _FakeRemote();
    final local = _FakeLocal();

    await CategoryMutationReplayer(
      remote,
      local,
    ).replay(_mutation(MutationOperation.update, '{"name":"bus"}'));

    expect(remote.updatedName, 'bus');
    expect(local.upserted.single.name, 'bus');
  });

  test('Success: delete replays the delete', () async {
    final remote = _FakeRemote();

    await CategoryMutationReplayer(
      remote,
      _FakeLocal(),
    ).replay(_mutation(MutationOperation.delete, null));

    expect(remote.deletedId, 2);
  });

  test('Success: replay sends the base version and the whole row', () async {
    final remote = _FakeRemote();
    final local = _FakeLocal();

    await CategoryMutationReplayer(remote, local).replay(
      _mutation(
        MutationOperation.update,
        '{"name":"bus","capacity":12}',
        baseVersion: 4,
      ),
    );

    expect(remote.sentBaseVersion, 4);
    expect(remote.patched, {'name': 'bus', 'capacity': 12});
    expect(local.upserted.single.capacity, 12);
  });

  test('Success: adopting the server row refreshes the cache', () async {
    final local = _FakeLocal();

    await CategoryMutationReplayer(
      _FakeRemote(),
      local,
    ).adoptServer({'id': 7, 'name': 'moto', 'capacity': 3, 'version': 9});

    expect(local.upserted.single.id, 7);
    expect(local.upserted.single.name, 'moto');
    expect(local.upserted.single.version, 9);
  });

  test('Security: adopting a missing server row is a no-op', () async {
    final local = _FakeLocal();

    await CategoryMutationReplayer(_FakeRemote(), local).adoptServer(null);

    expect(local.upserted, isEmpty);
  });

  test('Failure: remote failures propagate', () async {
    await expectLater(
      CategoryMutationReplayer(
        _FakeRemote(const NetworkFailure()),
        _FakeLocal(),
      ).replay(_mutation(MutationOperation.update, '{"name":"bus"}')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
