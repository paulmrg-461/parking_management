import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
import 'package:parking_management/features/check_out/presentation/check_out_page.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  @override
  Future<List<OpenSession>> listOpenSessions() async => [
        OpenSession(id: 1, vehicleId: 1, entryTime: DateTime(2026, 1, 1)),
      ];

  @override
  Future<CheckOutReceipt> checkOut(int sessionId, {DateTime? clientExitTime}) async {
    throw UnimplementedError();
  }
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
    'Success: renders the open sessions list resolved to plates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<CheckOutCubit>(
                create: (_) => CheckOutCubit(_FakeCheckOutRepository()),
              ),
              BlocProvider<VehiclesCubit>(
                create: (_) => VehiclesCubit(_FakeVehicleRepository()),
              ),
            ],
            child: const CheckOutPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Check out'), findsOneWidget);
      expect(find.text('Search by plate'), findsOneWidget);
    },
  );
}
