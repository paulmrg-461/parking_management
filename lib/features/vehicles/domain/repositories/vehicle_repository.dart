import '../../../../core/pagination/paged_result.dart';
import '../commands/create_vehicle_command.dart';
import '../commands/update_vehicle_command.dart';
import '../entities/vehicle.dart';

abstract class VehicleRepository {
  /// Every vehicle (lookups, plate maps). Prefer [listPage] for screens.
  Future<List<Vehicle>> list();

  /// One page (`limit`/`offset`, `X-Total-Count`); offline, sliced from the
  /// local cache.
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
  });

  Future<Vehicle?> findByPlate(String plate);

  Future<Vehicle> create(CreateVehicleCommand command);

  Future<Vehicle> update(UpdateVehicleCommand command);

  Future<void> delete(int id);
}
