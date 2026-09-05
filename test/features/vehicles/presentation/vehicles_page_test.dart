import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';
import 'package:parking_management/features/vehicles/presentation/vehicles_page.dart';

class _FakeVehicleRepository implements VehicleRepository {
  @override
  Future<List<Vehicle>> list() async =>
      const [Vehicle(id: 1, plate: 'ABC123', categoryId: 1, brand: 'Mazda')];

  @override
  Future<Vehicle?> findByPlate(String plate) async => null;

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async =>
      Vehicle(id: 2, plate: command.plate, categoryId: command.categoryId);

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async =>
      const Vehicle(id: 1, plate: 'ABC123', categoryId: 1);

  @override
  Future<void> delete(int id) async {}
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> list() async => const [Category(id: 1, name: 'carro')];

  @override
  Future<Category> create(String name) async => Category(id: 2, name: name);

  @override
  Future<Category> update(int id, String name) async =>
      Category(id: id, name: name);

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('renders vehicles with category names', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VehiclesCubit>(
            create: (_) => VehiclesCubit(_FakeVehicleRepository()),
          ),
          BlocProvider<CategoriesCubit>(
            create: (_) => CategoriesCubit(_FakeCategoryRepository()),
          ),
        ],
        child: const MaterialApp(home: VehiclesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('carro · Mazda'), findsOneWidget);
  });
}
