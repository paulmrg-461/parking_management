import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'models/vehicle_dto.dart';
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
      await _remote.delete(id, baseVersion: mutation.baseVersion);
      return;
    }
    await _local.upsert(
      await _remote.update(
        id,
        mutation.decodePayload(),
        baseVersion: mutation.baseVersion,
      ),
    );
  }

  @override
  Future<void> adoptServer(Map<String, dynamic>? row) async {
    if (row == null) {
      final id = _lastAdoptedId;
      if (id != null) {
        await _local.remove(id);
      }
      return;
    }
    final vehicle = VehicleDto.fromJson(row).toDomain();
    if (vehicle.id != null) {
      _lastAdoptedId = vehicle.id;
      await _local.upsert(vehicle);
    }
  }

  int? _lastAdoptedId;
}
