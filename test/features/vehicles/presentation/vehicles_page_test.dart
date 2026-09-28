import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/presentation/vehicles_page.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeVehicleRepository vehicles;

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Vehicle> initial = const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1, brand: 'Mazda'),
    ],
    Failure? listError,
  }) async {
    vehicles = FakeVehicleRepository(initial)..listError = listError;
    await tester.pumpWidget(
      BlocProvider<VehiclesCubit>(
        create: (_) => VehiclesCubit(
          vehicles,
          FakeCategoryRepository(const [Category(id: 1, name: 'carro')]),
        ),
        child: testApp(const VehiclesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Eliminar vehículo ABC123'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders vehicles with category names', (tester) async {
    await pumpPage(tester);

    expect(find.text('Vehículos'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('carro · Mazda'), findsOneWidget);
  });

  testWidgets('Success: a confirmed delete removes the vehicle', (
    tester,
  ) async {
    await pumpPage(tester);

    await confirmDelete(tester);

    expect(vehicles.deleted, [1]);
  });

  testWidgets('Failure: a failed delete keeps the list and shows a SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);
    vehicles.writeError = const ValidationFailure('Vehicle has open sessions');

    await confirmDelete(tester);

    expect(find.text('Vehicle has open sessions'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('Failure: load error offers retry; empty list shows empty state', (
    tester,
  ) async {
    await pumpPage(tester, initial: const [], listError: const ServerFailure());

    expect(find.text('Reintentar'), findsOneWidget);
    vehicles.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay vehículos registrados'), findsOneWidget);
  });

  testWidgets('Failure: create requires plate and normalizes it', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar vehículo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa la placa'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ).first,
      'xyz 999',
    );
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(vehicles.created?.plate, 'XYZ999');
    expect(vehicles.created?.categoryId, 1);
  });

  testWidgets(
    'Security: "Cargar más" only appears when X-Total-Count exceeds loaded',
    (tester) async {
      await pumpPage(tester);

      expect(find.text('Cargar más'), findsNothing);
    },
  );

  testWidgets('A11y: tooltips, 48dp targets and contrast', (tester) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
