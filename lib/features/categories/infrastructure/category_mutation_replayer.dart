import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'category_local_data_source.dart';
import 'category_remote_data_source.dart';
import 'models/category_dto.dart';

/// Replays queued category `update`/`delete` directly against the API.
class CategoryMutationReplayer extends MutationReplayer {
  CategoryMutationReplayer(this._remote, this._local);

  final CategoryRemoteDataSource _remote;
  final CategoryLocalDataSource _local;

  @override
  MutationEntity get entity => MutationEntity.category;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final id = mutation.entityId!;
    if (mutation.operation == MutationOperation.delete) {
      await _remote.delete(id, baseVersion: mutation.baseVersion);
      return;
    }
    // The repository queues the whole row (name + capacity) so replaying a
    // rename never drops a queued capacity change, and vice versa.
    await _local.upsert(
      await _remote.patch(
        id,
        mutation.decodePayload(),
        baseVersion: mutation.baseVersion,
      ),
    );
  }

  @override
  Future<void> adoptServer(Map<String, dynamic>? row) async {
    if (row == null) {
      return;
    }
    final category = CategoryDto.fromJson(row).toDomain();
    if (category.id != null) {
      await _local.upsert(category);
    }
  }
}
