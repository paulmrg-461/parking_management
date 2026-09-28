import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

/// In-memory [VehicleRepository]. [total] simulates `X-Total-Count`
/// (null = header absent); [pageRequests] records `(offset, limit)`.
class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository([List<Vehicle> vehicles = const []])
    : vehicles = List.of(vehicles);

  List<Vehicle> vehicles;
  int? total;
  Failure? listError;
  Failure? writeError;
  final List<(int, int)> pageRequests = [];
  final List<int> deleted = [];
  CreateVehicleCommand? created;

  @override
  Future<List<Vehicle>> list() async =>
      listError == null ? List.of(vehicles) : throw listError!;

  @override
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
  }) async {
    pageRequests.add((offset, limit));
    if (listError != null) {
      throw listError!;
    }
    return PagedResult(
      vehicles.skip(offset).take(limit).toList(),
      total: total,
    );
  }

  @override
  Future<Vehicle?> findByPlate(String plate) async {
    for (final vehicle in vehicles) {
      if (vehicle.plate == plate) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async {
    _throwIfWriteFails();
    created = command;
    final vehicle = Vehicle(
      id: vehicles.length + 100,
      plate: command.plate,
      categoryId: command.categoryId,
    );
    vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async {
    _throwIfWriteFails();
    return vehicles.firstWhere((v) => v.id == command.id);
  }

  @override
  Future<void> delete(int id) async {
    _throwIfWriteFails();
    deleted.add(id);
    vehicles.removeWhere((v) => v.id == id);
  }

  void _throwIfWriteFails() {
    if (writeError != null) {
      throw writeError!;
    }
  }
}
