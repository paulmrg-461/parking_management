import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/vehicle.dart';

abstract class VehicleLocalDataSource {
  Future<void> cacheAll(List<Vehicle> vehicles);

  Future<List<Vehicle>> readAll();
}

class HiveVehicleLocalDataSource implements VehicleLocalDataSource {
  static const _boxName = 'vehicles';

  Future<Box<Vehicle>> _box() => Hive.openBox<Vehicle>(_boxName);

  @override
  Future<void> cacheAll(List<Vehicle> vehicles) async {
    final box = await _box();
    await box.clear();
    for (final vehicle in vehicles) {
      if (vehicle.id != null) {
        await box.put(vehicle.id, vehicle);
      }
    }
  }

  @override
  Future<List<Vehicle>> readAll() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    return Hive.box<Vehicle>(_boxName).values.toList();
  }
}
