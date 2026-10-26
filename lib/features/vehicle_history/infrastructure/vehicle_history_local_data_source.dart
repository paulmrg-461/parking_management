import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/vehicle_history.dart';

abstract class VehicleHistoryLocalDataSource {
  Future<VehicleHistory?> read(String plate);

  Future<void> write(VehicleHistory history);
}

/// Offline copy of recently searched plates, so an operator can answer
/// questions during a network outage.
class HiveVehicleHistoryLocalDataSource
    implements VehicleHistoryLocalDataSource {
  static const _boxName = 'vehicle_history';

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  @override
  Future<VehicleHistory?> read(String plate) async {
    final raw = (await _box()).get(plate.toUpperCase());
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return VehicleHistory.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(VehicleHistory history) async {
    await (await _box()).put(history.plate, jsonEncode(history.toJson()));
  }
}
