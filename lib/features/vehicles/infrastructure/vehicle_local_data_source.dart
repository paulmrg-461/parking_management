import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/vehicle.dart';

abstract class VehicleLocalDataSource {
  Future<void> cacheAll(List<Vehicle> vehicles);

  Future<List<Vehicle>> readAll();

  Future<void> upsert(Vehicle vehicle);

  Future<void> remove(int id);
}

class HiveVehicleLocalDataSource implements VehicleLocalDataSource {
  static const _boxName = 'vehicles';

  /// Opens lazily on first use (returns the already-open box afterwards),
  /// so reads work on a cold start before any write happened.
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
    return (await _box()).values.toList();
  }

  @override
  Future<void> upsert(Vehicle vehicle) async {
    final id = vehicle.id;
    if (id == null) {
      return;
    }
    final box = await _box();
    await box.put(id, vehicle);
  }

  @override
  Future<void> remove(int id) async {
    final box = await _box();
    await box.delete(id);
  }
}
