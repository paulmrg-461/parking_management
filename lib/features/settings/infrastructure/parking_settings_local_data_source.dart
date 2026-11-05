import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../../core/lot/lot_session.dart';
import '../domain/entities/parking_settings.dart';

abstract class ParkingSettingsLocalDataSource {
  /// Caches [settings] for [lotId] (the active lot when `null`).
  Future<void> upsert(ParkingSettings settings, {int? lotId});

  Future<ParkingSettings?> read();

  Future<Uint8List?> readLogo(int version);

  Future<void> putLogo(int version, Uint8List bytes);
}

class HiveParkingSettingsLocalDataSource
    implements ParkingSettingsLocalDataSource {
  HiveParkingSettingsLocalDataSource(this._lots);

  final LotSession _lots;

  static const _boxName = 'parking_settings';
  static const _logoBoxName = 'logo_cache';

  /// One cached record per lot: switching sites must never render the other
  /// site's branding offline.
  String _key([int? lotId]) => 'current_${lotId ?? _lots.activeLotId ?? 1}';

  String _logoKey(int version) => '${_lots.activeLotId ?? 1}_$version';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<ParkingSettings>> _box() =>
      Hive.openBox<ParkingSettings>(_boxName);

  Future<Box<Uint8List>> _logoBox() => Hive.openBox<Uint8List>(_logoBoxName);

  @override
  Future<void> upsert(ParkingSettings settings, {int? lotId}) async =>
      (await _box()).put(_key(lotId), settings);

  @override
  Future<ParkingSettings?> read() async => (await _box()).get(_key());

  /// Keyed by `logo_version`, so a stale byte set can never be mistaken
  /// for the current logo.
  @override
  Future<Uint8List?> readLogo(int version) async =>
      (await _logoBox()).get(_logoKey(version));

  @override
  Future<void> putLogo(int version, Uint8List bytes) async =>
      (await _logoBox()).put(_logoKey(version), bytes);
}
