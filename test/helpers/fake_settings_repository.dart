import 'dart:typed_data';

import 'package:parking_management/core/error/failure.dart';

import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/settings/domain/repositories/parking_settings_repository.dart';

/// In-memory port fake for [SettingsCubit] tests.
class FakeParkingSettingsRepository implements ParkingSettingsRepository {
  FakeParkingSettingsRepository([ParkingSettings? initial])
    : settings = initial ?? ParkingSettings.defaults();

  ParkingSettings settings;
  ParkingSettings? cached;
  Uint8List? logoBytes;
  Failure? loadError;
  Failure? saveError;
  Failure? logoError;

  @override
  Future<ParkingSettings> load() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return settings;
  }

  @override
  Future<ParkingSettings?> loadCached() async => cached;

  @override
  Future<ParkingSettings> save(ParkingSettings next) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    settings = next;
    cached = next;
    return next;
  }

  @override
  Future<Uint8List?> loadLogo(int version) async =>
      version == settings.logoVersion ? logoBytes : null;

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    final error = logoError;
    if (error != null) {
      throw error;
    }
    logoBytes = bytes;
    settings = settings.copyWith(logoVersion: settings.logoVersion + 1);
    cached = settings;
    return settings;
  }
}
