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
  UpdateVehicleCommand? updated;

  @override
  Future<List<Vehicle>> list() async =>
      listError == null ? List.of(vehicles) : throw listError!;

  @override
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async {
    pageRequests.add((offset, limit));
    if (listError != null) {
      throw listError!;
    }
    final term = plate?.trim().toUpperCase() ?? '';
    final matched = term.isEmpty
        ? vehicles
        : [
            for (final vehicle in vehicles)
              if (vehicle.plate.toUpperCase().contains(term)) vehicle,
          ];
    return PagedResult(
      matched.skip(offset).take(limit).toList(),
      total: total ?? matched.length,
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
      ownerName: command.ownerName,
      ownerPhone: command.ownerPhone,
    );
    vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async {
    _throwIfWriteFails();
    updated = command;
    final index = vehicles.indexWhere((v) => v.id == command.id);
    final existing = vehicles[index];
    final merged = Vehicle(
      id: existing.id,
      plate: existing.plate,
      categoryId: command.categoryId ?? existing.categoryId,
      color: command.color ?? existing.color,
      brand: command.brand ?? existing.brand,
      ownerName: command.ownerName == null
          ? existing.ownerName
          : (command.ownerName!.trim().isEmpty
                ? null
                : command.ownerName!.trim()),
      ownerPhone: command.ownerPhone == null
          ? existing.ownerPhone
          : (command.ownerPhone!.trim().isEmpty
                ? null
                : command.ownerPhone!.trim()),
    );
    vehicles[index] = merged;
    return merged;
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
