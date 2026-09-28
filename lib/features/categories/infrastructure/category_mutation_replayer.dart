import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'category_local_data_source.dart';
import 'category_remote_data_source.dart';

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
      return _remote.delete(id);
    }
    final name = mutation.decodePayload()['name'] as String;
    await _local.upsert(await _remote.update(id, name));
  }
}
