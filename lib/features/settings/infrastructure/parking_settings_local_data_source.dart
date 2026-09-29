import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/parking_settings.dart';

abstract class ParkingSettingsLocalDataSource {
  Future<void> upsert(ParkingSettings settings);

  Future<ParkingSettings?> read();

  Future<Uint8List?> readLogo(int version);

  Future<void> putLogo(int version, Uint8List bytes);
}

class HiveParkingSettingsLocalDataSource
    implements ParkingSettingsLocalDataSource {
  static const _boxName = 'parking_settings';
  static const _logoBoxName = 'logo_cache';
  static const _key = 'current';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
  Future<Box<ParkingSettings>> _box() =>
      Hive.openBox<ParkingSettings>(_boxName);

  Future<Box<Uint8List>> _logoBox() => Hive.openBox<Uint8List>(_logoBoxName);

  @override
  Future<void> upsert(ParkingSettings settings) async =>
      (await _box()).put(_key, settings);

  @override
  Future<ParkingSettings?> read() async => (await _box()).get(_key);

  /// Keyed by `logo_version`, so a stale byte set can never be mistaken
  /// for the current logo.
  @override
  Future<Uint8List?> readLogo(int version) async =>
      (await _logoBox()).get(version);

  @override
  Future<void> putLogo(int version, Uint8List bytes) async =>
      (await _logoBox()).put(version, bytes);
}
