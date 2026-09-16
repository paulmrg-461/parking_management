import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/parking_session.dart';
import '../domain/repositories/check_in_repository.dart';
import 'check_in_remote_data_source.dart';

/// Check-in tries remote first, same as before. On `NetworkFailure` it now
/// persists the evidence photos to app-storage, queues a `checkIn`/`create`
/// mutation, and returns an optimistic session instead of rethrowing (see
/// `design.md` for why the synthetic id needs no reconciliation).
class CheckInRepositoryImpl implements CheckInRepository {
  CheckInRepositoryImpl(this._auth, this._remote, this._outbox, this._photos);

  final AuthRepository _auth;
  final CheckInRemoteDataSource _remote;
  final SyncOutbox _outbox;
  final PendingPhotoStorage _photos;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    try {
      return await _remote.createCheckIn(
        await _currentToken(),
        plate: plate,
        photos: photos,
      );
    } on NetworkFailure {
      return _queueCheckIn(plate: plate, photos: photos);
    }
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async {
    return _remote.listOpenSessions(await _currentToken());
  }

  Future<ParkingSession> _queueCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    final clientRef = _newClientRef();
    final entryTime = DateTime.now();
    final persistedPaths = await _photos.persist(
      clientRef: clientRef,
      photos: photos,
    );

    await _outbox.enqueue(
      PendingMutation(
        entityType: 'checkIn',
        operation: 'create',
        entityId: null,
        payloadJson: jsonEncode({
          'plate': plate,
          'photo_paths': persistedPaths,
          'client_entry_time': entryTime.toIso8601String(),
          'client_ref': clientRef,
        }),
        enqueuedAt: DateTime.now(),
      ),
    );

    return ParkingSession(
      id: -DateTime.now().microsecondsSinceEpoch,
      plate: plate,
      status: ParkingSessionStatus.pendingSync,
      entryTime: entryTime,
      photoCount: photos.length,
    );
  }

  /// A simple unique-enough string (timestamp + random suffix) used only as
  /// the photo subfolder name — never persisted server-side, never compared
  /// against a real id.
  String _newClientRef() {
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
