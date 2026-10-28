import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/widgets/qr_code.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/core/storage/key_value_store.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/notifications/application/notifications_cubit.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
import 'package:parking_management/features/check_out/presentation/check_out_page.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/fake_notification_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  Failure? checkOutError;
  Failure? previewError;
  int listCalls = 0;
  bool hasPass = false;
  CheckOutPreview? previewToReturn;
  bool? lastLostTicket;
  String? lastLostTicketReason;
  String? lastCardType;

  @override
  Future<TodaySummary> todaySummary() async => TodaySummary.empty;

  @override
  Future<SlotBoard> slotBoard() async => SlotBoard.empty;

  @override
  Future<CapacitySnapshot> capacitySnapshot() async => CapacitySnapshot.empty;

  @override
  Future<OccupancySnapshot> occupancy() async =>
      const OccupancySnapshot(totalOpen: 0, totalCapacity: 0);

  bool firstHasPass = false;

  static const _plates = {1: 'ABC123', 2: 'XYZ999'};

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async {
    listCalls++;
    final all = [
      OpenSession(
        id: 1,
        vehicleId: 1,
        entryTime: DateTime(2026, 1, 1),
        hasPass: firstHasPass,
        photoCount: 2,
        leftKeys: true,
      ),
      OpenSession(id: 2, vehicleId: 2, entryTime: DateTime(2026, 1, 1)),
    ];
    final query = plate?.trim().toUpperCase() ?? '';
    final items = query.isEmpty
        ? all
        : [
            for (final session in all)
              if (_plates[session.vehicleId]!.contains(query)) session,
          ];
    return PagedResult(items, total: items.length);
  }

  @override
  Future<CheckOutPreview> preview(int sessionId) async {
    final error = previewError;
    if (error != null) {
      throw error;
    }
    return previewToReturn ??
        CheckOutPreview(
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
    String? cardType,
    int? cashReceived,
  }) async {
    final error = checkOutError;
    if (error != null) throw error;
    lastLostTicket = lostTicket;
    lastLostTicketReason = lostTicketReason;
    lastCardType = cardType;
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
  late FakeNotificationRepository notifications;
  late NotificationsCubit notificationsCubit;

  Future<void> pumpPage(
    WidgetTester tester, {
    String? initialQuery,
    String? initialScan,
    bool firstHasPass = false,
    Future<String?> Function(BuildContext context)? scanQr,
    UserRole? role,
  }) async {
    repository = _FakeCheckOutRepository()..firstHasPass = firstHasPass;
    occupancy = FakeCheckOutRepository();
    notifications = FakeNotificationRepository();
    notificationsCubit = NotificationsCubit(notifications);
    addTearDown(notificationsCubit.close);
    final vehicles = FakeVehicleRepository(const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ]);
    final auth = AuthCubit(
      FakeAuthRepository(sessionToRestore: role == null ? null : sessionFor(role)),
    );
    if (role != null) {
      await auth.restore();
    }
    addTearDown(auth.close);
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            if (role != null) BlocProvider<AuthCubit>.value(value: auth),
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
            BlocProvider<NotificationsCubit>.value(
              value: notificationsCubit,
            ),
          ],
          child: CheckOutPage(
            initialQuery: initialQuery,
            scanPlate: initialScan,
            scanQr: scanQr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await notificationsCubit.start(1);
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
    await tester.ensureVisible(find.text('Ticket perdido'));
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
    await tester.ensureVisible(find.text('Ticket perdido'));
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

    expect(find.text('Total a cobrar'), findsOneWidget);
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

    expect(find.text('No se pudo calcular la tarifa'), findsOneWidget);
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

  testWidgets('Success: an initial plate arrives filtered and prefilled', (
    tester,
  ) async {
    await pumpPage(tester, initialQuery: 'XYZ');

    expect(find.text('ABC123'), findsNothing);
    expect(find.text('XYZ999'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'XYZ',
    );
  });

  testWidgets('Success: a car with an active pass is flagged in the list', (
    tester,
  ) async {
    await pumpPage(tester, firstHasPass: true);

    expect(find.text('Mensualidad'), findsOneWidget);
  });

  testWidgets('Success: no match offers to clear the search', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, 'QQQ');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ninguna placa'), findsOneWidget);
    expect(find.text('Limpiar búsqueda'), findsOneWidget);

    await tester.tap(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ999'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('Success: scanning a receipt QR opens its check-out', (
    tester,
  ) async {
    await pumpPage(tester, scanQr: (_) async => 'XYZ999');

    await tester.tap(find.byTooltip('Escanear el QR del recibo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('XYZ999'), findsWidgets);
    expect(find.text('Efectivo'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Failure: an unreadable QR explains itself', (tester) async {
    await pumpPage(tester, scanQr: (_) async => 'https://example.com/menu');

    await tester.tap(find.byTooltip('Escanear el QR del recibo'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo leer el código QR'), findsOneWidget);
  });

  testWidgets('Success: a USB reader types the plate and Enter charges it', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, 'xyz999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Efectivo'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Failure: a plate without an open session is reported', (
    tester,
  ) async {
    await pumpPage(tester, scanQr: (_) async => 'NOPE01');

    await tester.tap(find.byTooltip('Escanear el QR del recibo'));
    await tester.pumpAndSettle();

    expect(find.text('No hay una sesión abierta para NOPE01'), findsOneWidget);
  });

  testWidgets('Success: a scanned plate opens its check-out on arrival', (
    tester,
  ) async {
    await pumpPage(tester, initialScan: 'XYZ999');
    await tester.pumpAndSettle();

    expect(find.textContaining('XYZ999'), findsWidgets);
    expect(find.text('Efectivo'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Success: an admin can reprint an entry ticket', (tester) async {
    await pumpPage(tester, role: UserRole.admin);

    expect(find.byTooltip('Reimprimir recibo de entrada'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Reimprimir recibo de entrada').first);
    await tester.pumpAndSettle();

    expect(find.byType(QrCode), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
    expect(find.textContaining('2 fotos'), findsOneWidget);

    // The ticket dialog scrolls on short screens; close it programmatically.
    Navigator.of(tester.element(find.byType(QrCode))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('Security: operators do not get the reprint action', (
    tester,
  ) async {
    await pumpPage(tester, role: UserRole.operator);

    expect(find.byTooltip('Reimprimir recibo de entrada'), findsNothing);
  });

  testWidgets('A11y: the admin row fits a phone width', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpPage(tester, role: UserRole.admin);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Reimprimir recibo de entrada'), findsNWidgets(2));
  });

  testWidgets('Success: a car that left its keys is flagged', (tester) async {
    await pumpPage(tester);

    expect(find.text('Llaves'), findsOneWidget);
  });

  testWidgets('Success: the dialog explains the billed hours', (tester) async {
    await pumpPage(tester);
    repository.previewToReturn = const CheckOutPreview(
      sessionId: 1,
      amount: 22000,
      elapsedSeconds: 3900,
      dayHours: 2,
      nightHours: 1,
      days: 1,
      hourlyRate: 2000,
      nightlyRate: 8000,
      dailyRate: 30000,
      dailyCapApplied: true,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();

    expect(find.text('Tiempo: 1 h 5 min'), findsOneWidget);
    expect(find.text('2 h × \$2.000 (día)'), findsOneWidget);
    expect(find.text('1 h × \$8.000 (noche)'), findsOneWidget);
    expect(find.text('Tope diario aplicado (\$30.000)'), findsOneWidget);
    expect(find.text('\$22.000'), findsOneWidget);
  });

  testWidgets('Success: the on-screen keypad fills the search', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Teclado en pantalla'));
    await tester.pumpAndSettle();
    for (final key in ['A', 'B', 'C', '1', '2', '3']) {
      await tester.tap(find.widgetWithText(OutlinedButton, key));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ABC123'), findsWidgets);
  });

  testWidgets('Success: another device activity refreshes the list', (
    tester,
  ) async {
    await pumpPage(tester);
    final before = repository.listCalls;

    notifications.incoming.add(
      AppNotification(
        id: 51,
        type: 'check_in',
        title: 'Entrada registrada',
        body: 'Ana registró el ingreso de ABC123',
        createdAt: DateTime.now(),
        data: const {
          'action': 'check_in',
          'session_id': 12,
          'plate': 'ABC123',
          'actor_name': 'Ana',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(repository.listCalls, greaterThan(before));
  });

  testWidgets('Success: a card payment asks debit or credit', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crédito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crédito'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.lastCardType, 'credit');
  });
}
