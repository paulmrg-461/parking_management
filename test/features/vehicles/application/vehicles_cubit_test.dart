import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

class _FakeRepository implements VehicleRepository {
  _FakeRepository({this.listError});

  final Failure? listError;

  @override
  Future<List<Vehicle>> list() async {
    if (listError != null) {
      throw listError!;
    }
    return const [Vehicle(id: 1, plate: 'ABC123', categoryId: 1)];
  }

  @override
  Future<Vehicle?> findByPlate(String plate) async =>
      const Vehicle(id: 1, plate: 'ABC123', categoryId: 1);

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async =>
      Vehicle(id: 2, plate: command.plate, categoryId: command.categoryId);

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async =>
      const Vehicle(id: 1, plate: 'ABC123', categoryId: 1);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  test('load emits loaded state with vehicles', () async {
    final cubit = VehiclesCubit(_FakeRepository());

    await cubit.load();

    expect(cubit.state, isA<VehiclesLoaded>());
    expect((cubit.state as VehiclesLoaded).vehicles.single.plate, 'ABC123');
  });

  test('load failure emits failure state', () async {
    final cubit = VehiclesCubit(
      _FakeRepository(listError: const NetworkFailure('offline')),
    );

    await cubit.load();

    expect(cubit.state, isA<VehiclesFailure>());
  });

  test('create persists and reloads', () async {
    final cubit = VehiclesCubit(_FakeRepository());

    await cubit.create(
      const CreateVehicleCommand(plate: 'XYZ789', categoryId: 1),
    );

    expect(cubit.state, isA<VehiclesLoaded>());
  });
}
