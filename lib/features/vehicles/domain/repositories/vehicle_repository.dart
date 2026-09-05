import '../commands/create_vehicle_command.dart';
import '../commands/update_vehicle_command.dart';
import '../entities/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> list();

  Future<Vehicle?> findByPlate(String plate);

  Future<Vehicle> create(CreateVehicleCommand command);

  Future<Vehicle> update(UpdateVehicleCommand command);

  Future<void> delete(int id);
}
