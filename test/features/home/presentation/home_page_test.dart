import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/dashboard_trend.dart';
import 'package:parking_management/features/check_out/domain/entities/lot_setup_status.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/core/widgets/plate_text.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/home/domain/repositories/dashboard_cache.dart';
import 'package:parking_management/features/home/presentation/home_page.dart';
import 'package:parking_management/features/home/presentation/widgets/dashboard_widgets.dart';
import 'package:parking_management/features/home/presentation/widgets/slot_board_card.dart';
import 'package:parking_management/features/reservations/domain/entities/reservation.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/reservations/domain/repositories/reservation_repository.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/dashboard_fixtures.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_dashboard_cache.dart';
import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeCheckOutRepository> _pump(
  WidgetTester tester, {
  UserRole role = UserRole.operator,
  Failure? error,
  TodaySummary today = TodaySummary.empty,
  DashboardTrend trend = DashboardTrend.empty,
  Failure? trendError,
  LotSetupStatus setup = LotSetupStatus.unknown,
  Future<void>? todayGate,
  DashboardCache? cache,
  bool settle = true,
  int capacity = 0,
  CapacitySnapshot? space,
  SlotBoard? board,
  ReservationRepository? reservations,
  Size size = const Size(800, 1600),
}) async {
  // Tall viewport: the dashboard now stacks occupancy, capacity, the inside
  // list and today, so actions must stay reachable without scrolling.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sessions =
      FakeCheckOutRepository(
          capacity: capacity,
          sessions: [
            for (var i = 1; i <= 4; i++)
              OpenSession(
                id: i,
                vehicleId: i,
                entryTime: DateTime(2026),
                plate: const {1: 'ABC123', 2: 'XYZ999'}[i] ?? '',
              ),
          ],
          listError: error,
          today: today,
          trend: trend,
          trendError: trendError,
        )
        ..capacityToReturn = space ?? CapacitySnapshot.empty
        ..slotBoardToReturn = board ?? SlotBoard.empty
        ..setupToReturn = setup
        ..todayGate = todayGate;
  final auth = AuthCubit(
    FakeAuthRepository(sessionToRestore: sessionFor(role)),
  );
  await auth.restore();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider(
          create: (_) => DashboardCubit(sessions, cache: cache),
          child: HomePage(reservations: reservations),
        ),
        routes: [
          GoRoute(
            path: 'check-in',
            builder: (_, state) => _RoutePage('check-in page', state.uri),
          ),
          GoRoute(
            path: 'check-out',
            builder: (_, state) => _RoutePage('check-out page', state.uri),
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return sessions;
}

/// Stub destination that also shows the deep link it was opened with.
class _RoutePage extends StatelessWidget {
  const _RoutePage(this.name, this.uri);

  final String name;
  final Uri uri;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(name),
        Text(uri.query, key: const Key('route_query')),
      ],
    ),
  );
}

String _routeQuery(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('route_query'))).data ?? '';

DashboardTrend _week() => DashboardTrend(
  days: [
    for (var i = 0; i < 7; i++)
      TrendDay(
        date: DateTime(2026, 11, 3).add(Duration(days: i)),
        revenue: i * 1000,
        entries: i + 1,
        exits: i,
      ),
  ],
);

DashboardTrend _fortnight() => DashboardTrend(
  days: [
    for (var i = 0; i < 14; i++)
      TrendDay(
        date: DateTime(2026, 10, 27).add(Duration(days: i)),
        revenue: i * 1000,
        entries: i + 1,
        exits: i,
      ),
  ],
);

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

  testWidgets('Security: operators only see the management sections they '
      'may use', (tester) async {
    await _pump(tester);
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

    expect(find.text('Reservas'), findsOneWidget);
    expect(find.text('Reportes'), findsNothing);
    expect(find.text('Usuarios'), findsNothing);
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

  testWidgets('Success: the trend card sums the week and its totals', (
    tester,
  ) async {
    final trend = DashboardTrend(
      days: [
        for (var i = 0; i < 7; i++)
          TrendDay(
            date: DateTime(2026, 11, 3).add(Duration(days: i)),
            revenue: i * 1000,
            entries: i + 1,
            exits: i,
          ),
      ],
    );

    final sessions = await _pump(tester, trend: trend);

    expect(sessions.trendCalls, 1);
    expect(find.text('Tendencia'), findsOneWidget);
    expect(find.textContaining('21.000'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
  });

  testWidgets('Failure: a quiet week shows the empty trend message', (
    tester,
  ) async {
    await _pump(
      tester,
      trend: DashboardTrend(
        days: [
          for (var i = 0; i < 7; i++)
            TrendDay(date: DateTime(2026, 11, 3).add(Duration(days: i))),
        ],
      ),
    );

    expect(find.text('Sin movimientos en los últimos días'), findsOneWidget);
  });

  testWidgets('Success: the trend compares against the previous week', (
    tester,
  ) async {
    await _pump(
      tester,
      trend: DashboardTrend(
        days: [
          for (var i = 0; i < 14; i++)
            TrendDay(
              date: DateTime(2026, 10, 27).add(Duration(days: i)),
              revenue: i < 7 ? 10000 : 15000,
            ),
        ],
      ),
    );

    expect(find.text('+50 % vs semana anterior'), findsOneWidget);
    expect(find.textContaining('105.000'), findsOneWidget);
  });

  testWidgets('Success: a weaker week is flagged as a warning', (tester) async {
    await _pump(
      tester,
      trend: DashboardTrend(
        days: [
          for (var i = 0; i < 14; i++)
            TrendDay(
              date: DateTime(2026, 10, 27).add(Duration(days: i)),
              revenue: i < 7 ? 10000 : 5000,
            ),
        ],
      ),
    );

    expect(find.text('-50 % vs semana anterior'), findsOneWidget);
  });

  testWidgets('Success: an even week says it matches the previous one', (
    tester,
  ) async {
    await _pump(
      tester,
      trend: DashboardTrend(
        days: [
          for (var i = 0; i < 14; i++)
            TrendDay(
              date: DateTime(2026, 10, 27).add(Duration(days: i)),
              revenue: 5000,
            ),
        ],
      ),
    );

    expect(find.text('Igual que la semana anterior'), findsOneWidget);
  });

  testWidgets('Success: the home paints card skeletons until it loads', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(tester, todayGate: gate.future, settle: false);

    expect(find.byType(SkeletonCard), findsNWidgets(4));
    expect(find.byType(OccupancyCard), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonCard), findsNothing);
    expect(find.text('Vehículos dentro'), findsWidgets);
  });

  testWidgets('Failure: a broken trend never hides the rest of the home', (
    tester,
  ) async {
    await _pump(tester, trendError: const NetworkFailure('offline'));

    expect(find.text('Sin movimientos en los últimos días'), findsOneWidget);
    expect(find.text('Vehículos dentro'), findsWidgets);
  });

  testWidgets('Failure: a broken dashboard says the trend is unavailable', (
    tester,
  ) async {
    await _pump(tester, error: const NetworkFailure('offline'));

    expect(find.text('Tendencia no disponible'), findsOneWidget);
  });

  testWidgets('Security: only admins get the reports shortcut', (tester) async {
    await _pump(tester, trend: _week());

    expect(find.byTooltip('Abrir reportes'), findsNothing);
  });

  testWidgets('Success: admins open the reports screen from the trend', (
    tester,
  ) async {
    await _pump(tester, role: UserRole.admin, trend: _week());

    expect(find.byTooltip('Abrir reportes'), findsOneWidget);
  });

  testWidgets('Success: offline shows the cached KPIs with a stale notice', (
    tester,
  ) async {
    final cache = FakeDashboardCache()..snapshot = sampleDashboardSnapshot();
    await _pump(tester, error: const NetworkFailure('offline'), cache: cache);

    expect(
      find.text('Sin conexión · datos guardados de las 14:32'),
      findsOneWidget,
    );
    expect(find.textContaining('25.000'), findsWidgets);
    expect(find.byType(SlotBoardCard), findsNothing);
    expect(find.byType(InsideCard), findsNothing);
  });

  testWidgets('Success: an unfinished site guides admins through setup', (
    tester,
  ) async {
    await _pump(
      tester,
      role: UserRole.admin,
      setup: const LotSetupStatus(categories: 1),
    );

    expect(find.text('Primeros pasos'), findsOneWidget);
    expect(find.text('1 de 4 listos'), findsOneWidget);
    expect(find.text('Tarifas'), findsOneWidget);
    expect(find.text('Datos del parqueadero'), findsOneWidget);
  });

  testWidgets('Security: operators never see the setup card', (tester) async {
    await _pump(tester, setup: const LotSetupStatus(categories: 1));

    expect(find.text('Primeros pasos'), findsNothing);
  });

  testWidgets('Success: a ready site hides the setup card', (tester) async {
    await _pump(
      tester,
      role: UserRole.admin,
      setup: const LotSetupStatus(
        categories: 1,
        tariffs: 1,
        carCapacity: 10,
        hasAddress: true,
        hasPhone: true,
      ),
    );

    expect(find.text('Primeros pasos'), findsNothing);
  });

  testWidgets('A11y: the trend card fits a phone with large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, size: const Size(400, 2200), trend: _fortnight());

    expect(tester.takeException(), isNull);
    expect(find.text('Tendencia'), findsOneWidget);
    expect(find.textContaining('vs semana anterior'), findsOneWidget);
  });

  testWidgets('A11y: reduced motion fills the occupancy bar immediately', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pump(tester, capacity: 8);

    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
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
    final capacityCard = tester
        .getTopLeft(find.text('Capacidad del parqueadero'))
        .dx;
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

  testWidgets('Success: operators get the holds shortcut too', (tester) async {
    await _pump(
      tester,
      capacity: 8,
      space: const CapacitySnapshot(reservationsActive: 3),
    );

    expect(find.text('3 reservas activas'), findsOneWidget);
    await tester.tap(find.text('Ver reservas'));
    await tester.pumpAndSettle();
    expect(find.text('reservations page'), findsOneWidget);
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
    expect(find.textContaining('HOLD01'), findsOneWidget);

    // The map has its own "Reservas" filter chip; the management tile sits
    // further down and would make find.text ambiguous.
    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Reservas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BRD001'), findsNothing);
    expect(find.textContaining('HOLD01'), findsOneWidget);
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

    expect(find.bySemanticsLabel(RegExp('^Ocupado BRD001')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Reservado HOLD01')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Libre Carros')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('A11y: space cells keep cabin-sized tap targets', (tester) async {
    await _pump(tester, capacity: 8, board: const SlotBoard(carCapacity: 4));

    final cell = tester.getSize(find.byTooltip('Libre Carros y camionetas 1'));
    expect(cell.width, greaterThanOrEqualTo(44));
    expect(cell.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Success: a free cell starts a check-in, never a charge', (
    tester,
  ) async {
    await _pump(tester, capacity: 8, board: const SlotBoard(carCapacity: 4));

    await tester.tap(find.byTooltip('Libre Carros y camionetas 1'));
    await tester.pumpAndSettle();

    expect(find.text('Total a cobrar'), findsNothing);
    expect(find.text('check-in page'), findsOneWidget);
    expect(_routeQuery(tester), isEmpty);
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

  testWidgets('Success: an admin releases a hold from the board', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(hours: 1));
    final holds = FakeReservationRepository([
      Reservation(id: 5, plate: 'HOLD01', categoryId: 1, reservedUntil: until),
    ]);
    await _pump(
      tester,
      role: UserRole.admin,
      capacity: 8,
      reservations: holds,
      board: SlotBoard(
        carCapacity: 2,
        holds: [SlotHold(plate: 'HOLD01', until: until)],
      ),
    );

    // The exact label is time-dependent; the plate is enough to find the cell.
    final holdCell = find.byTooltip(RegExp('Reservado HOLD01')).first;
    await tester.ensureVisible(holdCell);
    await tester.pumpAndSettle();
    await tester.tap(holdCell);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Cancelar reserva'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar reserva'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar reserva'));
    await tester.pumpAndSettle();

    expect(holds.cancelledId, 5);
    expect(find.text('Reserva cancelada'), findsOneWidget);
  });

  testWidgets('Security: operators cannot release a hold from the board', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(hours: 1));
    final holds = FakeReservationRepository([
      Reservation(id: 5, plate: 'HOLD01', categoryId: 1, reservedUntil: until),
    ]);
    await _pump(
      tester,
      capacity: 8,
      reservations: holds,
      board: SlotBoard(
        carCapacity: 2,
        holds: [SlotHold(plate: 'HOLD01', until: until)],
      ),
    );

    final holdCell = find.byTooltip(RegExp('Reservado HOLD01')).first;
    await tester.ensureVisible(holdCell);
    await tester.pumpAndSettle();
    await tester.tap(holdCell);
    await tester.pumpAndSettle();

    expect(find.text('Cancelar reserva'), findsNothing);
    expect(holds.cancelledId, isNull);
  });

  testWidgets('Success: the map paints the real bays and their cars', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: SlotBoard(
        spots: const [
          ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
          ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
          ParkingSpot(
            id: 3,
            code: 'A3',
            group: SlotGroup.car,
            row: 1,
            col: 0,
            active: false,
          ),
        ],
        sessions: [
          SlotSession(
            sessionId: 9,
            plate: 'ABC123',
            entryTime: DateTime.now().subtract(const Duration(minutes: 20)),
            spotId: 1,
          ),
        ],
      ),
    );

    final bay = find.byTooltip(RegExp('^Ocupado ABC123, A1'));
    expect(bay, findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('Mant.'), findsOneWidget);
    // Empty holes are exactly the same size as the filled bays.
    final empty = tester.getSize(find.byKey(const ValueKey('empty_1_1')));
    expect(empty.width, tester.getSize(bay).width);
    expect(empty.height, tester.getSize(bay).height);

    await tester.tap(bay);
    await tester.pumpAndSettle();

    expect(find.text('Espacio A1'), findsOneWidget);
    expect(find.text('Total a cobrar'), findsOneWidget);
  });

  testWidgets('Success: a free mapped bay opens check-in with that bay', (
    tester,
  ) async {
    await _pump(
      tester,
      capacity: 8,
      board: const SlotBoard(
        spots: [
          ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
          ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Libre A2'));
    await tester.pumpAndSettle();

    expect(find.text('check-in page'), findsOneWidget);
    expect(_routeQuery(tester), 'spot=2');
  });

  testWidgets('A11y: free cells are announced as buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, capacity: 8, board: const SlotBoard(carCapacity: 4));

    expect(
      tester.getSemantics(find.byTooltip('Libre Carros y camionetas 1')),
      containsSemantics(label: 'Libre Carros y camionetas 1', isButton: true),
    );
    semantics.dispose();
  });

  testWidgets('A11y: large text is clamped and scaled inside a cell', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      capacity: 8,
      size: const Size(800, 3200),
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

    expect(tester.takeException(), isNull);
    final plate = find.text('BRD001');
    final scaler = MediaQuery.textScalerOf(tester.element(plate));
    expect(scaler.scale(10), closeTo(13, 0.01));
  });

  testWidgets('Success: an inside row opens its charge directly', (
    tester,
  ) async {
    await _pump(tester, capacity: 8);

    await tester.tap(find.text('ABC123'));
    await tester.pumpAndSettle();

    expect(find.text('check-out page'), findsOneWidget);
    expect(_routeQuery(tester), 'scan=ABC123');
  });

  testWidgets('A11y: inside plates use the shared plate style', (tester) async {
    await _pump(tester, capacity: 8);

    final text = tester.widget<Text>(find.text('ABC123'));
    final expected = PlateText.styleFor(
      tester.element(find.text('ABC123')),
      PlateSize.medium,
    );
    expect(text.style?.fontFamily, expected.fontFamily);
    expect(text.style?.fontFeatures, expected.fontFeatures);
  });
}
