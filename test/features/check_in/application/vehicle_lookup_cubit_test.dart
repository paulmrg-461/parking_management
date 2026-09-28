import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/check_in/application/vehicle_lookup_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

class _FakeVehicleRepository implements VehicleRepository {
  _FakeVehicleRepository({this.vehicles = const {}, this.error});

  final Map<String, Vehicle> vehicles;
  final Failure? error;
  final List<String> lookedUp = [];
  final Map<String, Completer<void>> gates = {};

  @override
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
  }) => throw UnimplementedError();

  @override
  Future<Vehicle?> findByPlate(String plate) async {
    lookedUp.add(plate);
    await gates[plate]?.future;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return vehicles[plate];
  }

  @override
  Future<List<Vehicle>> list() => throw UnimplementedError();

  @override
  Future<Vehicle> create(CreateVehicleCommand command) =>
      throw UnimplementedError();

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.categories = const [], this.error});

  final List<Category> categories;
  final Failure? error;

  @override
  Future<List<Category>> list() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return categories;
  }

  @override
  Future<Category> create(String name) => throw UnimplementedError();

  @override
  Future<Category> update(int id, String name) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

void main() {
  const car = Category(id: 1, name: 'Car');
  const moto = Category(id: 2, name: 'Motorcycle');
  const vehicle = Vehicle(
    id: 7,
    plate: 'ABC123',
    categoryId: 1,
    color: 'Red',
    brand: 'Mazda',
  );

  VehicleLookupCubit build({
    _FakeVehicleRepository? vehicles,
    _FakeCategoryRepository? categories,
  }) => VehicleLookupCubit(
    vehicles ?? _FakeVehicleRepository(),
    categories ?? _FakeCategoryRepository(categories: const [car, moto]),
  );

  test(
    'Success: existing plate emits Found with the resolved category name',
    () async {
      final vehicles = _FakeVehicleRepository(vehicles: {'ABC123': vehicle});
      final cubit = build(vehicles: vehicles);

      await cubit.lookup(' abc 123 ');

      expect(vehicles.lookedUp, ['ABC123']);
      expect(
        cubit.state,
        const VehicleLookupFound(vehicle, categoryName: 'Car'),
      );
    },
  );

  test(
    'Success: unknown plate emits NotFound with the categories to pick from',
    () async {
      final cubit = build();

      await cubit.lookup('XYZ999');

      expect(cubit.state, const VehicleLookupNotFound([car, moto]));
    },
  );

  test(
    'Success: Found still succeeds (without name) when categories fail to load',
    () async {
      final cubit = build(
        vehicles: _FakeVehicleRepository(vehicles: {'ABC123': vehicle}),
        categories: _FakeCategoryRepository(
          error: const NetworkFailure('offline'),
        ),
      );

      await cubit.lookup('ABC123');

      expect(cubit.state, const VehicleLookupFound(vehicle));
    },
  );

  test('Failure: repository failure emits VehicleLookupFailure', () async {
    final cubit = build(
      vehicles: _FakeVehicleRepository(
        error: const AuthenticationFailure('Not authenticated'),
      ),
    );

    await cubit.lookup('ABC123');

    expect(cubit.state, const VehicleLookupFailure('Not authenticated'));
  });

  test(
    'Failure: NotFound but categories fail to load emits VehicleLookupFailure',
    () async {
      final cubit = build(
        categories: _FakeCategoryRepository(
          error: const NetworkFailure('offline'),
        ),
      );

      await cubit.lookup('XYZ999');

      expect(cubit.state, const VehicleLookupFailure('offline'));
    },
  );

  test(
    'Security: empty/whitespace plate goes Idle without hitting the repository',
    () async {
      final vehicles = _FakeVehicleRepository();
      final cubit = build(vehicles: vehicles);

      await cubit.lookup('   ');

      expect(cubit.state, const VehicleLookupIdle());
      expect(vehicles.lookedUp, isEmpty);
    },
  );

  test(
    'Security: a stale (slower) lookup never overwrites the latest result',
    () async {
      final vehicles = _FakeVehicleRepository(vehicles: {'ABC123': vehicle});
      final gate = Completer<void>();
      vehicles.gates['ABC123'] = gate;
      final cubit = build(vehicles: vehicles);

      final stale = cubit.lookup('ABC123');
      await cubit.lookup('XYZ999');
      gate.complete();
      await stale;

      expect(cubit.state, const VehicleLookupNotFound([car, moto]));
    },
  );

  test('reset returns to Idle and discards in-flight results', () async {
    final vehicles = _FakeVehicleRepository(vehicles: {'ABC123': vehicle});
    final gate = Completer<void>();
    vehicles.gates['ABC123'] = gate;
    final cubit = build(vehicles: vehicles);

    final pending = cubit.lookup('ABC123');
    cubit.reset();
    gate.complete();
    await pending;

    expect(cubit.state, const VehicleLookupIdle());
  });

  test('repeated lookup of the same resolved plate does not hit the repository again', () async {
    final vehicles = _FakeVehicleRepository(vehicles: {'ABC123': vehicle});
    final cubit = build(vehicles: vehicles);

    await cubit.lookup('ABC123');
    await cubit.lookup('abc123');

    expect(vehicles.lookedUp, ['ABC123']);
  });
}
