import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/application/spots_cubit.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/domain/entities/spot_event.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/spots/presentation/spots_page.dart';

import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_spot_repository.dart';
import '../../../helpers/test_app.dart';

Future<SpotsCubit> pumpPage(
  WidgetTester tester,
  FakeSpotRepository repository, {
  bool isAdmin = true,
  CapacitySnapshot? capacity,
  Size size = const Size(900, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = SpotsCubit(repository);
  addTearDown(cubit.close);
  final dashboard = DashboardCubit(
    FakeCheckOutRepository()
      ..capacityToReturn = capacity ?? CapacitySnapshot.empty,
  );
  addTearDown(dashboard.close);
  await dashboard.load();
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<SpotsCubit>.value(value: cubit),
          BlocProvider<DashboardCubit>.value(value: dashboard),
        ],
        child: SpotsPage(isAdmin: isAdmin),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

FakeSpotRepository sampleRepository() => FakeSpotRepository(const [
  ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
  ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
]);

void main() {
  testWidgets('Success: the editor paints the bays', (tester) async {
    await pumpPage(tester, sampleRepository());

    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('Mapa del parqueadero'), findsOneWidget);
  });

  testWidgets('Failure: only admins see the editor controls', (tester) async {
    await pumpPage(tester, sampleRepository(), isAdmin: false);

    expect(
      find.text('Solo un administrador puede editar el mapa'),
      findsOneWidget,
    );
    expect(find.text('Agregar espacio'), findsNothing);
  });

  testWidgets('Success: adding a spot takes the first free cell', (
    tester,
  ) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('Agregar espacio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot_code')), 'A3');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.spots, hasLength(3));
    final added = repository.spots.last;
    expect(added.code, 'A3');
    expect(added.row, 0);
    expect(added.col, 2);
  });

  testWidgets('Success: tapping a bay edits its code', (tester) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot_edit_code')), 'B1');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.spots.first.code, 'B1');
  });

  testWidgets('Success: taking a bay out of service sends the reason', (
    tester,
  ) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spot_reason')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('spot_reason')),
      'fuga de aceite',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.lastReason, 'fuga de aceite');
    expect(repository.spots.first.active, isFalse);
  });

  testWidgets('Failure: a too-short reason blocks the status change', (
    tester,
  ) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot_reason')), 'ab');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe al menos 3 caracteres o déjalo vacío'),
      findsOneWidget,
    );
    expect(repository.lastReason, isNull);
    expect(find.byKey(const Key('spot_edit_code')), findsOneWidget);
  });

  testWidgets('Success: the history dialog lists the transitions', (
    tester,
  ) async {
    final repository = sampleRepository();
    repository.events = [
      SpotEvent(
        id: 9,
        spotId: 1,
        spotCode: 'A1',
        active: true,
        actorName: 'Ana',
        createdAt: DateTime(2026, 11, 9, 12),
      ),
      SpotEvent(
        id: 8,
        spotId: 1,
        spotCode: 'A1',
        active: false,
        reason: 'pintura',
        actorName: 'Paul',
        createdAt: DateTime(2026, 11, 9, 10),
      ),
    ];
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();

    expect(find.text('Historial de A1'), findsOneWidget);
    expect(find.textContaining('pintura'), findsOneWidget);
    expect(find.textContaining('Paul'), findsOneWidget);
    expect(find.textContaining('Ana'), findsOneWidget);
  });

  testWidgets('Success: an untouched bay explains its empty history', (
    tester,
  ) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();

    expect(find.text('Sin cambios de estado'), findsOneWidget);
  });

  testWidgets('Failure: a failed history offers a retry', (tester) async {
    final repository = sampleRepository();
    repository.eventsError = const NetworkFailure('offline');
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();

    expect(find.text('No hay conexión con el servidor'), findsOneWidget);

    repository.eventsError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin cambios de estado'), findsOneWidget);
  });

  testWidgets('A11y: the maintenance sheet and history fit a phone', (
    tester,
  ) async {
    final repository = sampleRepository();
    repository.events = [
      SpotEvent(
        id: 9,
        spotId: 1,
        spotCode: 'A1',
        active: false,
        reason: 'fuga de aceite en el motor, revisar mañana temprano',
        actorName: 'Paul Realpe',
        createdAt: DateTime(2026, 11, 9, 10),
      ),
    ];
    await pumpPage(tester, repository, size: const Size(400, 2200));

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver historial'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Historial de A1'), findsOneWidget);
    expect(find.textContaining('Paul Realpe'), findsOneWidget);
  });

  testWidgets('Success: dragging a bay moves it on the grid', (tester) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    final start = tester.getCenter(find.text('A1'));
    final target = tester.getCenter(find.text('2-2'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = repository.spots.firstWhere((spot) => spot.code == 'A1');
    expect(moved.row, 1);
    expect(moved.col, 1);
  });

  testWidgets('Success: the map shows progress against the configured spots', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sampleRepository(),
      capacity: const CapacitySnapshot(carCapacity: 3),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carros y camionetas 2 de 3'), findsOneWidget);
    expect(find.text('Faltan 1'), findsOneWidget);
    expect(
      find.text(
        'El mapa debe tener exactamente los espacios configurados en Ajustes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a full group cannot take another bay', (tester) async {
    final repository = sampleRepository();
    await pumpPage(
      tester,
      repository,
      capacity: const CapacitySnapshot(carCapacity: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carros y camionetas 2 de 2'), findsOneWidget);
    await tester.tap(find.text('Agregar espacio'));
    await tester.pumpAndSettle();

    // Only heavy (no limit) is available; the car option is disabled.
    await tester.tap(find.byType(DropdownButtonFormField<SlotGroup>));
    await tester.pumpAndSettle();
    final car = tester.widget<DropdownMenuItem<SlotGroup>>(
      find
          .widgetWithText(DropdownMenuItem<SlotGroup>, 'Carros y camionetas')
          .last,
    );
    expect(car.enabled, isFalse);
  });

  testWidgets('Success: the drawn bays do not change the configured target', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sampleRepository(),
      capacity: const CapacitySnapshot(carCapacity: 2, carTargetCapacity: 4),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carros y camionetas 2 de 4'), findsOneWidget);
    expect(find.text('Faltan 2'), findsOneWidget);
  });
}
