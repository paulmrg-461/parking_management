import 'dart:typed_data';

import '../entities/parking_settings.dart';

/// Offline-first access to the singleton parking-settings record and logo.
abstract class ParkingSettingsRepository {
  /// Remote → cache → defaults (usable when fully offline).
  Future<ParkingSettings> load();

  /// Hive only: startup seed with no network round-trip.
  Future<ParkingSettings?> loadCached();

  /// Optimistic local save + outbox queue when the backend is unreachable.
  Future<ParkingSettings> save(ParkingSettings settings);

  /// Logo bytes for [version]; fetches and caches them when missing.
  /// `null` when there is no logo or it cannot be fetched offline.
  Future<Uint8List?> loadLogo(int version);

  /// Online only by design: bytes are never queued. Throws `NetworkFailure`
  /// offline with the cached logo untouched.
  Future<ParkingSettings> uploadLogo(Uint8List bytes);
}
