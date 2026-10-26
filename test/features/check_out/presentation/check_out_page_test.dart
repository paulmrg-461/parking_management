import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/core/storage/key_value_store.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
import 'package:parking_management/features/check_out/presentation/check_out_page.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  Failure? checkOutError;
  Failure? previewError;
  bool hasPass = false;
  bool? lastLostTicket;
  String? lastLostTicketReason;

  @override
  Future<TodaySummary> todaySummary() async => TodaySummary.empty;

  @override
  Future<OccupancySnapshot> occupancy() async =>
      const OccupancySnapshot(totalOpen: 0, totalCapacity: 0);

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async => PagedResult([
    OpenSession(id: 1, vehicleId: 1, entryTime: DateTime(2026, 1, 1)),
    OpenSession(id: 2, vehicleId: 2, entryTime: DateTime(2026, 1, 1)),
  ]);

  @override
  Future<CheckOutPreview> preview(int sessionId) async {
    final error = previewError;
    if (error != null) {
      throw error;
    }
    return CheckOutPreview(
      sessionId: sessionId,
      amount: hasPass ? 0 : 5000,
      hasPass: hasPass,
    );
  }


  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
  }) async {
    final error = checkOutError;
    if (error != null) throw error;
    lastLostTicket = lostTicket;
    lastLostTicketReason = lostTicketReason;
    return CheckOutReceipt(
      id: sessionId,
      plate: sessionId == 1 ? 'ABC123' : 'XYZ999',
      entryTime: DateTime(2026, 1, 1, 8),
      exitTime: DateTime(2026, 1, 1, 10),
      amountCharged: 5000,
      ticketNumber: 'TCK-000001',
    );
  }
}

void main() {
  late _FakeCheckOutRepository repository;
  late FakeCheckOutRepository occupancy;

  Future<void> pumpPage(WidgetTester tester) async {
    repository = _FakeCheckOutRepository();
    occupancy = FakeCheckOutRepository();
    final vehicles = FakeVehicleRepository(const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ]);
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<CheckOutCubit>(
              create: (_) => CheckOutCubit(
                CheckOutVehicle(repository),
                repository,
                vehicles,
                searchDebounce: Duration.zero,
              ),
            ),
            BlocProvider<DashboardCubit>(
              create: (_) => DashboardCubit(occupancy),
            ),
          ],
          child: const CheckOutPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders the open sessions list resolved to plates', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ999'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Cobrar'), findsNWidgets(2));
    expect(find.text('Buscar por placa'), findsOneWidget);
    // Sessions entered in 2026-01 are long stays by the test clock.
    expect(find.text('Más de 24 h'), findsNWidgets(2));
    expect(find.textContaining('h'), findsWidgets);
  });

  testWidgets('Success: searching filters the list through the cubit', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsNothing);
    expect(find.text('XYZ999'), findsOneWidget);
  });

  testWidgets('Success: a closed session refreshes the vehicles-inside count', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Generar recibo'), findsOneWidget);
    expect(occupancy.occupancyCalls, 1);
  });

  testWidgets(
    'Failure: a failed check-out keeps the list and shows a SnackBar',
    (tester) async {
      await pumpPage(tester);
      repository.checkOutError = const ValidationFailure(
        'Session already closed',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Session already closed'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
      expect(occupancy.occupancyCalls, 0);
    },
  );

  testWidgets('Success: lost ticket charges the full rate with a reason', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ticket perdido'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo (ticket perdido)'),
      'cliente sin ticket',
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.lastLostTicket, isTrue);
    expect(repository.lastLostTicketReason, 'cliente sin ticket');
  });

  testWidgets('Failure: a lost ticket without a reason is not submitted', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ticket perdido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Indica el motivo del ticket perdido'), findsOneWidget);
    expect(repository.lastLostTicket, isNull);
  });

  testWidgets(
    'Security: a broken occupancy source cannot break the receipt flow',
    (tester) async {
      await pumpPage(tester);
      occupancy.listError = const NetworkFailure('offline');

      await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Generar recibo'), findsOneWidget);
      expect(occupancy.occupancyCalls, 1);
    },
  );

  testWidgets('Success: the checkout dialog shows the estimated fare', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Total estimado'), findsOneWidget);
    expect(find.textContaining('5.000'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Failure: a broken preview still opens the payment dialog', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.previewError = const NetworkFailure('offline');

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Total estimado'), findsNothing);
    expect(find.text('Efectivo'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  });

  RadioListTile<PaymentMethod> methodTile(
    WidgetTester tester,
    String label,
  ) => tester.widget<RadioListTile<PaymentMethod>>(
    find.widgetWithText(RadioListTile<PaymentMethod>, label),
  );

  testWidgets('Success: the last payment method is preselected', (
    tester,
  ) async {
    final store = FakeKeyValueStore()
      ..values['preferences/last_payment_method'] = 'card';
    serviceLocator.registerSingleton<KeyValueStore>(store);
    addTearDown(serviceLocator.reset);

    await pumpPage(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(methodTile(tester, 'Tarjeta').groupValue, PaymentMethod.card);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Success: a completed check-out remembers the method', (
    tester,
  ) async {
    final store = FakeKeyValueStore();
    serviceLocator.registerSingleton<KeyValueStore>(store);
    addTearDown(serviceLocator.reset);

    await pumpPage(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(store.values['preferences/last_payment_method'], 'transfer');
  });

  testWidgets('Security: no remembered monthly pass is reused without one', (
    tester,
  ) async {
    final store = FakeKeyValueStore()
      ..values['preferences/last_payment_method'] = 'monthly_pass';
    serviceLocator.registerSingleton<KeyValueStore>(store);
    addTearDown(serviceLocator.reset);

    await pumpPage(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(methodTile(tester, 'Efectivo').groupValue, PaymentMethod.cash);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Success: a pass-covered session preselects the pass', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.hasPass = true;

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(
      methodTile(tester, 'Mensualidad').groupValue,
      PaymentMethod.monthlyPass,
    );
    expect(find.textContaining('sin cobro'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Success: Nuevo cobro clears the search for the next car', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField).first, 'XYZ');
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cobro'));
    await tester.pumpAndSettle();

    // Dialog closed, query cleared and the cursor is ready for the next plate.
    expect(find.text('Nuevo cobro'), findsNothing);
    expect(find.text('ABC123'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });
}
