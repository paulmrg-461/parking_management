import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'vehicle_local_data_source.dart';
import 'vehicle_remote_data_source.dart';

/// Replays queued vehicle `update`/`delete` directly against the API.
class VehicleMutationReplayer extends MutationReplayer {
  VehicleMutationReplayer(this._remote, this._local);

  final VehicleRemoteDataSource _remote;
  final VehicleLocalDataSource _local;

  @override
  MutationEntity get entity => MutationEntity.vehicle;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final id = mutation.entityId!;
    if (mutation.operation == MutationOperation.delete) {
      return _remote.delete(id);
    }
    await _local.upsert(await _remote.update(id, mutation.decodePayload()));
  }
}
