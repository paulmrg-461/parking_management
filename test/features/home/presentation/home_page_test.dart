import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/home/presentation/home_page.dart';
import 'package:parking_management/features/home/presentation/widgets/dashboard_widgets.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeCheckOutRepository> _pump(
  WidgetTester tester, {
  UserRole role = UserRole.operator,
  Failure? error,
  TodaySummary today = TodaySummary.empty,
  int capacity = 0,
  CapacitySnapshot? space,
  SlotBoard? board,
  Size size = const Size(800, 1600),
}) async {
  // Tall viewport: the dashboard now stacks occupancy, capacity, the inside
  // list and today, so actions must stay reachable without scrolling.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sessions = FakeCheckOutRepository(
    capacity: capacity,
    sessions: [
      for (var i = 1; i <= 4; i++)
        OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026)),
    ],
    listError: error,
    today: today,
  )
    ..capacityToReturn = space ?? CapacitySnapshot.empty
    ..slotBoardToReturn = board ?? SlotBoard.empty;
  final auth = AuthCubit(FakeAuthRepository(sessionToRestore: sessionFor(role)));
  await auth.restore();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider(
          create: (_) => DashboardCubit(
            sessions,
            FakeVehicleRepository(const [
              Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
              Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
            ]),
          ),
          child: const HomePage(),
        ),
        routes: [
          GoRoute(
            path: 'check-in',
            builder: (_, _) => const Scaffold(body: Text('check-in page')),
          ),
          GoRoute(
            path: 'check-out',
            builder: (_, _) => const Scaffold(body: Text('check-out page')),
          ),
          GoRoute(
            path: 'reservations',
            builder: (_, _) => const Scaffold(body: Text('reservations page')),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    BlocProvider<BrandingCubit>.value(
      value: BrandingCubit(FakeParkingSettingsRepository()),
      child: BlocProvider.value(value: auth, child: testRouterApp(router)),
    ),
  );
  await tester.pumpAndSettle();
  return sessions;
}

void main() {
  testWidgets('Success: operator dashboard shows occupancy and actions', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Hola, Juan'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Vehículos dentro'), findsWidgets);

    await tester.tap(find.text('Entrada'));
    await tester.pumpAndSettle();
    expect(find.text('check-in page'), findsOneWidget);
  });

  testWidgets('Success: Salida opens the check-out flow', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Salida'));
    await tester.pumpAndSettle();

    expect(find.text('check-out page'), findsOneWidget);
  });

  testWidgets('Failure: occupancy error offers a retry, actions still work', (
    tester,
  ) async {
    final sessions = await _pump(
      tester,
      error: const NetworkFailure('offline'),
    );

    expect(find.text('Ocupación no disponible'), findsOneWidget);
    sessions.listError = null;
    await tester.tap(find.byTooltip('Actualizar ocupación'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
  });

  testWidgets('Security: operators do not see the management section', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Gestión'), findsNothing);
  });

  testWidgets('Success: admins get management shortcuts', (tester) async {
    await _pump(tester, role: UserRole.admin);
    await tester.scrollUntilVisible(
      find.text('Gestión'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Gestión'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);
  });

  testWidgets('A11y: tap targets, labels and contrast', (tester) async {
    await _pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('Success: a quiet day shows a friendly zero state', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Sin movimientos hoy'), findsOneWidget);
  });

  testWidgets('Success: today card shows revenue and traffic', (tester) async {
    await _pump(
      tester,
      today: const TodaySummary(
        revenue: 45000,
        cashRevenue: 30000,
        passRevenue: 80000,
        entries: 6,
        exits: 5,
      ),
    );

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.textContaining('45.000'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('30.000'), findsOneWidget);
    expect(find.text('Mensualidades'), findsOneWidget);
  });

  testWidgets('A11y: reduced motion fills the occupancy bar immediately', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await _pump(tester, capacity: 8);

    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      0.5,
    );
  });

  testWidgets('Success: the capacity dashboard shows spaces and keys', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      space: const CapacitySnapshot(
        carOpen: 4,
        carCapacity: 10,
        carReserved: 2,
        motoOpen: 1,
        motoCapacity: 5,
        keysOpen: 2,
        keyCapacity: 3,
      ),
    );

    expect(find.text('Capacidad del parqueadero'), findsOneWidget);
    expect(find.text('Carros y camionetas'), findsOneWidget);
    expect(find.text('4 / 10'), findsOneWidget);
    expect(find.text('Motos'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('Vehículos con llaves'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    // The big occupancy uses the configured spaces (cars 4+1 of 10+5).
    expect(find.text('5 / 15'), findsOneWidget);
    expect(find.text('2 reservados'), findsOneWidget);
  });

  testWidgets('Success: the home lists the cars inside', (tester) async {
    await _pump(tester, capacity: 8);

    expect(find.text('Vehículos dentro'), findsWidgets);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ999'), findsOneWidget);
    expect(find.text('Ver todos'), findsOneWidget);

    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.text('check-out page'), findsOneWidget);
  });

  testWidgets('Failure: no limit is shown without a configured capacity', (
    tester,
  ) async {
    await _pump(tester, capacity: 8);

    expect(find.textContaining('sin límite'), findsWidgets);
  });

  testWidgets('Success: wide screens move the inside list to a side panel', (
    tester,
  ) async {
    await _pump(tester, capacity: 8, size: const Size(1400, 1000));

    final inside = find.descendant(
      of: find.byType(InsideCard),
      matching: find.text('Vehículos dentro'),
    );
    expect(inside, findsOneWidget);
    final panel = tester.getTopLeft(inside).dx;
    final capacityCard = tester.getTopLeft(
      find.text('Capacidad del parqueadero'),
    ).dx;
    expect(panel, greaterThan(capacityCard));
  });

  testWidgets('Success: active holds are summarized with a shortcut', (
    tester,
  ) async {
    await _pump(
      tester,
      role: UserRole.admin,
      capacity: 8,
      space: const CapacitySnapshot(
        reservationsActive: 3,
        reservationsExpiring: 1,
      ),
    );

    expect(find.text('3 reservas activas'), findsOneWidget);
    expect(find.text('1 por vencer'), findsOneWidget);
    await tester.tap(find.text('Ver reservas'));
    await tester.pumpAndSettle();
    expect(find.text('reservations page'), findsOneWidget);
  });

  testWidgets('Security: operators do not get the holds shortcut', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      space: const CapacitySnapshot(reservationsActive: 3),
    );

    expect(find.text('3 reservas activas'), findsOneWidget);
    expect(find.text('Ver reservas'), findsNothing);
  });

  testWidgets('Success: the space map paints free, occupied and held cells', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: SlotBoard(
        carCapacity: 4,
        motoCapacity: 2,
        sessions: [
          SlotSession(
            sessionId: 9,
            plate: 'BRD001',
            entryTime: DateTime(2026, 1, 1),
          ),
          SlotSession(
            sessionId: 10,
            plate: 'BRD002',
            entryTime: DateTime(2026, 1, 1),
          ),
        ],
        holds: [
          SlotHold(
            plate: 'HOLD01',
            until: DateTime.now().add(const Duration(hours: 1)),
          ),
        ],
      ),
    );

    expect(find.text('Mapa de espacios'), findsOneWidget);
    expect(find.text('3 libres'), findsOneWidget);
    expect(find.text('BRD001'), findsOneWidget);
    expect(find.text('HOLD01'), findsOneWidget);

    await tester.tap(find.text('Reservas'));
    await tester.pumpAndSettle();
    expect(find.text('BRD001'), findsNothing);
    expect(find.text('HOLD01'), findsOneWidget);
  });

  testWidgets('Success: an occupied cell opens its details and check-out', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: SlotBoard(
        carCapacity: 4,
        sessions: [
          SlotSession(
            sessionId: 9,
            plate: 'BRD001',
            entryTime: DateTime(2026, 1, 1),
          ),
        ],
      ),
    );

    await tester.tap(find.text('BRD001'));
    await tester.pumpAndSettle();

    expect(find.text('Total a cobrar'), findsOneWidget);
    expect(find.textContaining('5.000'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Salida'));
    await tester.pumpAndSettle();
    expect(find.text('check-out page'), findsOneWidget);
  });

  testWidgets('Success: occupancy adds a radial gauge on top of the bar', (
    tester,
  ) async {
    await _pump(tester, capacity: 8);

    expect(find.text('50%'), findsOneWidget);
    final gauge = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(gauge.value, closeTo(0.5, 0.001));
  });

  testWidgets('A11y: space cells announce state, plate and group', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      capacity: 8,
      board: SlotBoard(
        carCapacity: 4,
        sessions: [
          SlotSession(
            sessionId: 9,
            plate: 'BRD001',
            entryTime: DateTime(2026, 1, 1),
          ),
        ],
        holds: [
          SlotHold(
            plate: 'HOLD01',
            until: DateTime.now().add(const Duration(hours: 1)),
          ),
        ],
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('^Ocupado BRD001')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Reservado HOLD01')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^Libre Carros')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('A11y: space cells keep cabin-sized tap targets', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: const SlotBoard(carCapacity: 4),
    );

    final cell = tester.getSize(find.byTooltip('Libre Carros y camionetas 1'));
    expect(cell.width, greaterThanOrEqualTo(44));
    expect(cell.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Security: a free cell opens nothing', (tester) async {
    await _pump(
      tester,
      capacity: 8,
      board: const SlotBoard(carCapacity: 4),
    );

    await tester.tap(find.byTooltip('Libre Carros y camionetas 1'));
    await tester.pumpAndSettle();

    expect(find.text('Total a cobrar'), findsNothing);
    expect(find.text('check-out page'), findsNothing);
  });

  testWidgets('Success: out-of-service spots are painted and never offered', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      space: const CapacitySnapshot(
        carOpen: 3,
        carCapacity: 8,
        carOutOfService: 2,
      ),
      board: SlotBoard(
        carCapacity: 4,
        carOutOfService: 1,
        sessions: [
          SlotSession(
            sessionId: 9,
            plate: 'BRD001',
            entryTime: DateTime(2026, 1, 1),
          ),
        ],
      ),
    );

    // 4 configured - 1 occupied - 1 in maintenance = 2 free.
    expect(find.text('2 libres'), findsOneWidget);
    expect(find.text('Mantenimiento'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);

    // The dashboard counts only usable spots (8 - 2 = 6).
    expect(find.text('3 / 6'), findsWidgets);
    expect(find.text('2 fuera de servicio'), findsWidgets);
  });

  testWidgets('Security: maintenance cells are not interactive', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: const SlotBoard(carCapacity: 2, carOutOfService: 2),
    );

    final cell = find.byTooltip('Mantenimiento Carros y camionetas').first;
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(find.text('Total a cobrar'), findsNothing);
  });
}
