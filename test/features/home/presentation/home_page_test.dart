import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/home/presentation/home_page.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeCheckOutRepository> _pump(
  WidgetTester tester, {
  UserRole role = UserRole.operator,
  Failure? error,
}) async {
  final sessions = FakeCheckOutRepository(
    sessions: [
      for (var i = 1; i <= 4; i++)
        OpenSession(id: i, vehicleId: i, entryTime: DateTime(2026)),
    ],
    listError: error,
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
    BlocProvider.value(value: auth, child: testRouterApp(router)),
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
}
