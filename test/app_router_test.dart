import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

import 'helpers/app_harness.dart';

void main() {
  group('Router (F-RT)', () {
    testWidgets('redirects unauthenticated users to the login page', (tester) async {
      await pumpApp(tester);

      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('shows the home page for authenticated users', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      expect(find.text('Hola, Juan'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('Success: logout lands on /login (no infinite spinner)', (tester) async {
      await pumpApp(tester, role: UserRole.operator);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Success: an expired session (sessionExpired) returns to /login', (tester) async {
      final auth = await pumpApp(tester, role: UserRole.admin);

      await auth.sessionExpired();
      await tester.pumpAndSettle();

      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('Success: admin can open /users', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/users');

      expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    });

    testWidgets('Security: operator typing /users is redirected home', (tester) async {
      await pumpApp(tester, role: UserRole.operator);

      await goTo(tester, '/users');

      expect(find.widgetWithText(AppBar, 'Usuarios'), findsNothing);
      expect(find.text('Hola, Juan'), findsOneWidget);
    });
  });

  group('Navigation (F-NAV)', () {
    testWidgets('Success: sub-pages show a back arrow that returns home', (tester) async {
      await pumpApp(tester, role: UserRole.admin);
      await goTo(tester, '/users');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Juan'), findsOneWidget);
    });

    testWidgets('Failure: Android back from a sub-page goes home, not out of the app', (tester) async {
      await pumpApp(tester, role: UserRole.admin);
      await goTo(tester, '/users');

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('Hola, Juan'), findsOneWidget);
    });
  });
}
