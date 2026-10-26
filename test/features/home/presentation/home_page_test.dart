import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/home/presentation/home_page.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeCheckOutRepository> _pump(
  WidgetTester tester, {
  UserRole role = UserRole.operator,
  Failure? error,
  TodaySummary today = TodaySummary.empty,
  int capacity = 0,
}) async {
  final sessions = FakeCheckOutRepository(
    capacity: capacity,
    sessions: [
      for (var i = 1; i <= 4; i++)
        OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026)),
    ],
    listError: error,
    today: today,
  );
  final auth = AuthCubit(FakeAuthRepository(sessionToRestore: sessionFor(role)));
  await auth.restore();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider(
          create: (_) => DashboardCubit(sessions),
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
    expect(find.text('Vehículos dentro'), findsOneWidget);

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
    await tester.scrollUntilVisible(find.text('Gestión'), 200);
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
}
