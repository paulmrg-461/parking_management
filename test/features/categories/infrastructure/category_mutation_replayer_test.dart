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

  @override
  Future<Category> update(int id, String name) async {
    if (error != null) {
      throw error!;
    }
    updatedName = name;
    return Category(id: id, name: name);
  }

  @override
  Future<void> delete(int id) async => deletedId = id;

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

PendingMutation _mutation(MutationOperation op, String? payload) =>
    PendingMutation(
      entityType: MutationEntity.category,
      operation: op,
      entityId: 2,
      payloadJson: payload,
      enqueuedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('Success: update replays the rename and refreshes the cache', () async {
    final remote = _FakeRemote();
    final local = _FakeLocal();

    await CategoryMutationReplayer(remote, local)
        .replay(_mutation(MutationOperation.update, '{"name":"bus"}'));

    expect(remote.updatedName, 'bus');
    expect(local.upserted.single.name, 'bus');
  });

  test('Success: delete replays the delete', () async {
    final remote = _FakeRemote();

    await CategoryMutationReplayer(remote, _FakeLocal())
        .replay(_mutation(MutationOperation.delete, null));

    expect(remote.deletedId, 2);
  });

  test('Failure: remote failures propagate', () async {
    await expectLater(
      CategoryMutationReplayer(_FakeRemote(const NetworkFailure()), _FakeLocal())
          .replay(_mutation(MutationOperation.update, '{"name":"bus"}')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
