import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/vehicle_history/application/vehicle_history_cubit.dart';
import 'package:parking_management/features/vehicle_history/domain/entities/vehicle_history.dart';
import 'package:parking_management/features/vehicle_history/presentation/vehicle_history_page.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_vehicle_history_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: searches a plate and renders its timeline', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'abc 123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('TCK-000002'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(repository.lookups, ['ABC123']);
  });

  testWidgets('Failure: an unknown plate shows the localized error', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(
      error: const ValidationFailure(
        'VehicleNotFoundError',
        'VehicleNotFoundError',
      ),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ZZZ999');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Vehículo no encontrado'), findsOneWidget);
  });

  testWidgets('Success: notes can be added from the history card', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar nota'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'rayon puerta',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.lastNotes, 'rayon puerta');
    expect(find.text('rayon puerta'), findsOneWidget);
  });

  testWidgets('Security: only admins see the blacklist action', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bloquear vehículo'), findsNothing);
  });

  testWidgets('Success: an admin blocks the vehicle after confirming', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    final auth = AuthCubit(
      FakeAuthRepository(sessionToRestore: sessionFor(UserRole.admin)),
    );
    addTearDown(auth.close);
    await auth.restore();
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider.value(value: cubit),
          ],
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bloquear vehículo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear vehículo').last);
    await tester.pumpAndSettle();

    expect(repository.lastBlacklisted, isTrue);
    expect(find.text('Bloqueado'), findsOneWidget);
  });

  testWidgets('Success: sessions are filtered and tagged by site', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both sites show up as chips, and the filter defaults to all.
    expect(find.text('Central'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('TCK-000002'), findsOneWidget);
    expect(find.text('TCK-000001'), findsOneWidget);

    await tester.tap(find.text('Todas las sedes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North').last);
    await tester.pumpAndSettle();

    expect(find.text('TCK-000001'), findsOneWidget);
    expect(find.text('TCK-000002'), findsNothing);
  });

  testWidgets('Success: a closed session can reprint its ticket', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reprint = find.byTooltip('Reimprimir ticket').first;
    await tester.ensureVisible(reprint);
    await tester.pumpAndSettle();
    await tester.tap(reprint);
    await tester.pumpAndSettle();

    expect(find.text('Generar recibo'), findsOneWidget);
    // The summary rebuilds the same numbers as the original receipt.
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.textContaining('7.000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Success: a customer phone offers the WhatsApp actions', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(
      history: sampleHistory(ownerPhone: '+57 300 111 2233'),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+57 300 111 2233'), findsOneWidget);
    expect(find.byTooltip('Enviar recibo por WhatsApp'), findsWidgets);
    expect(find.text('Agregar teléfono'), findsNothing);
  });

  testWidgets('Success: a plate without a phone can add one', (tester) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar teléfono'), findsOneWidget);

    await tester.tap(find.text('Agregar teléfono'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '+57 300 111 2233');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.lastOwnerPhone, '+57 300 111 2233');
  });

  testWidgets('Success: an open session can notify that the car is ready', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(
      history: VehicleHistory(
        plate: 'ABC123',
        vehicleId: 1,
        categoryName: 'car',
        visits: 1,
        totalSpent: 0,
        openSessions: 1,
        ownerPhone: '+57 300 111 2233',
        sessions: [
          VehicleHistorySession(
            id: 9,
            entryTime: DateTime.utc(2026, 10, 24, 8),
            status: 'open',
          ),
        ],
      ),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(initialPlate: 'ABC123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Avisar que está listo'), findsOneWidget);
    expect(find.byTooltip('Enviar recibo por WhatsApp'), findsNothing);
  });
}
