import 'dart:convert';

import 'package:cross_file/cross_file.dart';

import '../../../core/error/failure.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import '../domain/repositories/check_in_repository.dart';
import 'check_in_remote_data_source.dart';

/// Check-in tries remote first, same as before. On `NetworkFailure` it now
/// persists the evidence photos to app-storage, queues a `checkIn`/`create`
/// mutation, and returns an optimistic session instead of rethrowing (see
/// `design.md` for why the synthetic id needs no reconciliation).
class CheckInRepositoryImpl implements CheckInRepository {
  CheckInRepositoryImpl(this._remote, this._outbox, this._photos);

  final CheckInRemoteDataSource _remote;
  final SyncOutbox _outbox;
  final PendingPhotoStorage _photos;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    try {
      return await _remote.createCheckIn(
        plate: plate,
        photos: photos,
        newVehicle: newVehicle,
      );
    } on NetworkFailure {
      return _queueCheckIn(
        plate: plate,
        photos: photos,
        newVehicle: newVehicle,
      );
    }
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() => _remote.listOpenSessions();

  Future<ParkingSession> _queueCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    final clientRef = newClientRef();
    final entryTime = DateTime.now().toUtc();
    final persistedPaths = await _photos.persist(
      clientRef: clientRef,
      photos: photos,
    );

    await _outbox.enqueue(
      PendingMutation(
        entityType: MutationEntity.checkIn,
        operation: MutationOperation.create,
        entityId: null,
        payloadJson: jsonEncode({
          'plate': plate,
          'photo_paths': persistedPaths,
          'client_entry_time': entryTime.toIso8601String(),
          'client_ref': clientRef,
          ..._newVehiclePayload(newVehicle),
        }),
        enqueuedAt: DateTime.now(),
      ),
    );

    return ParkingSession(
      id: -DateTime.now().microsecondsSinceEpoch,
      plate: plate,
      status: ParkingSessionStatus.pendingSync,
      entryTime: entryTime.toLocal(),
      photoCount: photos.length,
    );
  }

  /// Keys mirror the multipart field names so `SyncService` can replay them.
  Map<String, Object?> _newVehiclePayload(NewVehicleInfo? info) {
    if (info == null) {
      return const {};
    }
    return {
      'category_id': info.categoryId,
      'color': info.color,
      'brand': info.brand,
    };
  }
}
