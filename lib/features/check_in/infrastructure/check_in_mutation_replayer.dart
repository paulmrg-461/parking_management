import '../../../core/sync/mutation_replayer.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../domain/entities/new_vehicle_info.dart';
import 'check_in_remote_data_source.dart';

/// Re-submits a queued check-in with its persisted photos, using the queued
/// `client_ref` as `Idempotency-Key`; cleans the photo folder on success.
class CheckInMutationReplayer extends MutationReplayer {
  CheckInMutationReplayer(this._remote, this._photos);

  final CheckInRemoteDataSource _remote;
  final PendingPhotoStorage _photos;

  @override
  MutationEntity get entity => MutationEntity.checkIn;

  @override
  Future<void> replay(PendingMutation mutation) async {
    final payload = mutation.decodePayload();
    final clientRef = payload['client_ref'] as String;
    final paths = (payload['photo_paths'] as List<dynamic>).cast<String>();
    await _remote.createCheckIn(
      plate: payload['plate'] as String,
      photos: await _photos.load(paths),
      newVehicle: _newVehicleFrom(payload),
      leftKeys: payload['left_keys'] == true,
      spotId: (payload['spot_id'] as num?)?.toInt(),
      idempotencyKey: clientRef,
      clientEntryTime: switch (payload['client_entry_time']) {
        final String value => DateTime.parse(value),
        _ => null, // legacy queue entry written before this field existed
      },
      lotId: (payload['lot_id'] as num?)?.toInt(),
    );
    await _photos.deleteFor(clientRef);
  }

  @override
  Future<void> discard(PendingMutation mutation) async {
    final clientRef = mutation.decodePayload()['client_ref'];
    if (clientRef is String) {
      await _photos.deleteFor(clientRef);
    }
  }

  /// `null` when the plate was already registered (no `category_id`).
  NewVehicleInfo? _newVehicleFrom(Map<String, dynamic> payload) {
    final categoryId = payload['category_id'] as int?;
    if (categoryId == null) {
      return null;
    }
    return NewVehicleInfo(
      categoryId: categoryId,
      color: payload['color'] as String?,
      brand: payload['brand'] as String?,
    );
  }
}
