import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import 'models/parking_session_dto.dart';

abstract class CheckInRemoteDataSource {
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    bool leftKeys = false,
    String? idempotencyKey,
    DateTime? clientEntryTime,
    int? lotId,
  });

  Future<List<ParkingSession>> listOpenSessions();
}

class SupabaseCheckInRemoteDataSource implements CheckInRemoteDataSource {
  SupabaseCheckInRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _bucket = 'evidence';
  static const _view = 'open_sessions_view';

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    bool leftKeys = false,
    String? idempotencyKey,
    DateTime? clientEntryTime,
    int? lotId,
  }) async {
    try {
      final paths = await _uploadPhotos(
        photos,
        existingIdempotencyKey: idempotencyKey,
      );
      final result = await _client.rpc(
        'check_in',
        params: {
          'p_plate': plate,
          if (newVehicle?.categoryId != null)
            'p_category_id': newVehicle!.categoryId,
          if (newVehicle?.color != null) 'p_color': newVehicle!.color,
          if (newVehicle?.brand != null) 'p_brand': newVehicle!.brand,
          'p_photos': [
            for (final path in paths)
              {
                'path': path,
                'taken_at': DateTime.now().toUtc().toIso8601String(),
              },
          ],
          'p_left_keys': leftKeys,
          'p_idempotency_key': ?idempotencyKey,
          if (clientEntryTime != null)
            'p_client_entry_time': clientEntryTime.toUtc().toIso8601String(),
          'p_lot_id': ?lotId,
        },
      );
      return ParkingSessionDto.fromJson(
        Map<String, dynamic>.from(result as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<String>> _uploadPhotos(
    List<XFile> photos, {
    String? existingIdempotencyKey,
  }) async {
    if (photos.isEmpty) {
      return const [];
    }
    final folder =
        existingIdempotencyKey ?? DateTime.now().microsecondsSinceEpoch;
    final paths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final extension = photoExtensionOf(photo);
      final path =
          '$folder/${i}_${DateTime.now().microsecondsSinceEpoch}$extension';
      await _uploadPhoto(
        path,
        await photo.readAsBytes(),
        contentType: photoMimeType(extension),
      );
      paths.add(path);
    }
    return paths;
  }

  /// Insert-only: storage cannot allow `upsert` here because its conflict
  /// probe needs the SELECT policy, and evidence is only readable once a photo
  /// row exists (written by `check_in`, after the upload). A path collision
  /// means an earlier attempt of the same queued entry already stored that
  /// exact photo, so it is safe to continue.
  Future<void> _uploadPhoto(
    String path,
    List<int> bytes, {
    required String contentType,
  }) async {
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType),
          );
    } on StorageException catch (error) {
      if (!isDuplicateUpload(error)) {
        rethrow;
      }
    }
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async {
    const pageSize = 500;
    final sessions = <ParkingSession>[];
    var offset = 0;
    try {
      while (true) {
        final rows = await _client
            .from(_view)
            .select()
            .order('entry_time')
            .range(offset, offset + pageSize - 1);
        sessions.addAll(
          rows.map((row) => ParkingSessionDto.fromJson(row).toDomain()),
        );
        if (rows.length < pageSize) {
          return sessions;
        }
        offset += rows.length;
      }
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

/// `true` when the object already exists (a replayed upload), never for a
/// permission failure.
bool isDuplicateUpload(StorageException error) =>
    error.statusCode == '409' || error.error == 'Duplicate';
