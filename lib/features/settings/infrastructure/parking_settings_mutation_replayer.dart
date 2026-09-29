import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'parking_settings_local_data_source.dart';
import 'parking_settings_remote_data_source.dart';

/// Replays a queued settings edit as `PATCH /api/settings` and refreshes the
/// cache with the authoritative merged record.
class ParkingSettingsMutationReplayer extends MutationReplayer {
  ParkingSettingsMutationReplayer(this._remote, this._local);

  final ParkingSettingsRemoteDataSource _remote;
  final ParkingSettingsLocalDataSource _local;

  @override
  MutationEntity get entity => MutationEntity.settings;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final saved = await _remote.patch(mutation.decodePayload());
    await _local.upsert(saved);
  }
}
