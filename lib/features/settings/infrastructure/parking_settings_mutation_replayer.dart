import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import 'parking_settings_local_data_source.dart';
import 'parking_settings_remote_data_source.dart';

/// Replays a queued settings edit through PostgREST and refreshes the
/// cache with the authoritative merged record.
///
/// The edit lands in the lot captured at enqueue time (`lot_id`), even after
/// a lot switch; legacy payloads without it fall back to the active lot.
class ParkingSettingsMutationReplayer extends MutationReplayer {
  ParkingSettingsMutationReplayer(this._remote, this._local);

  final ParkingSettingsRemoteDataSource _remote;
  final ParkingSettingsLocalDataSource _local;

  @override
  MutationEntity get entity => MutationEntity.settings;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final fields = mutation.decodePayload();
    final lotId = fields.remove('lot_id') as int?;
    final saved = await _remote.patch(fields, lotId: lotId);
    await _local.upsert(saved, lotId: lotId);
  }
}
