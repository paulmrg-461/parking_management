import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/create_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/update_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/domain/repositories/monthly_pass_repository.dart';
import 'package:parking_management/features/monthly_passes/presentation/monthly_passes_page.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

class _FakeMonthlyPassRepository implements MonthlyPassRepository {
  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async => [
        MonthlyPass(
          id: 1,
          vehicleId: 1,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          amount: 100000,
        ),
      ];

  @override
  Future<MonthlyPass> create(CreateMonthlyPassCommand command) async =>
      MonthlyPass(
        id: 2,
        vehicleId: command.vehicleId,
        startDate: command.startDate,
        endDate: command.endDate,
        amount: command.amount,
      );

  @override
  Future<MonthlyPass> update(UpdateMonthlyPassCommand command) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) async {}
}

class _FakeVehicleRepository implements VehicleRepository {
  @override
  Future<List<Vehicle>> list() async => [
        const Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      ];

  @override
  Future<Vehicle?> findByPlate(String plate) async => null;

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets(
    'Success: renders monthly passes with resolved plates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<MonthlyPassesCubit>(
                create: (_) => MonthlyPassesCubit(_FakeMonthlyPassRepository()),
              ),
              BlocProvider<VehiclesCubit>(
                create: (_) => VehiclesCubit(_FakeVehicleRepository()),
              ),
            ],
            child: const MonthlyPassesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('2026-01-01 - 2026-01-31 · 100000 COP'), findsOneWidget);
    },
  );
}
