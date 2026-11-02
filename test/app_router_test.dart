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
      await tester.tap(find.text('Menú'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('Success: logout lands on /login (no infinite spinner)', (tester) async {
      await pumpApp(tester, role: UserRole.operator);

      await tester.tap(find.text('Menú'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Success: an expired session (sessionExpired) returns to /login', (tester) async {
      final auth = await pumpApp(tester, role: UserRole.admin);

      await auth.sessionExpired();
      await tester.pumpAndSettle();

      expect(find.text('Ingresar'), findsOneWidget);
      expect(
        find.text('Tu sesión expiró. Ingresa de nuevo para continuar.'),
        findsOneWidget,
      );
    });

    testWidgets('Failure: an unknown route shows the friendly error page', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/does-not-exist');

      expect(find.text('Página no encontrada'), findsWidgets);
      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);
    });

    testWidgets('Success: admin can open /users', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/users');

      expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    });

    testWidgets('Success: admin can open /diagnostics', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/diagnostics');

      expect(find.widgetWithText(AppBar, 'Diagnóstico'), findsOneWidget);
    });

    testWidgets('Security: operator typing /diagnostics is redirected home', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.operator);

      await goTo(tester, '/diagnostics');

      expect(find.widgetWithText(AppBar, 'Diagnóstico'), findsNothing);
      expect(find.text('Hola, Juan'), findsOneWidget);
    });

    testWidgets('Success: admin can open /audit', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/audit');

      expect(find.widgetWithText(AppBar, 'Auditoría'), findsOneWidget);
    });

    testWidgets('Security: operator typing /audit is redirected home', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.operator);

      await goTo(tester, '/audit');

      expect(find.widgetWithText(AppBar, 'Auditoría'), findsNothing);
      expect(find.text('Hola, Juan'), findsOneWidget);
    });

    testWidgets('Success: admin can open /lots', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/lots');

      expect(find.widgetWithText(AppBar, 'Sedes del parqueadero'), findsOneWidget);
    });

    testWidgets('Security: operator typing /lots is redirected home', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.operator);

      await goTo(tester, '/lots');

      expect(
        find.widgetWithText(AppBar, 'Sedes del parqueadero'),
        findsNothing,
      );
      expect(find.text('Hola, Juan'), findsOneWidget);
    });

    testWidgets('Success: admin can open /reservations', (tester) async {
      await pumpApp(tester, role: UserRole.admin);

      await goTo(tester, '/reservations');

      expect(find.widgetWithText(AppBar, 'Reservas de cupo'), findsOneWidget);
    });

    testWidgets('Security: operator typing /reservations is redirected home', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.operator);

      await goTo(tester, '/reservations');

      expect(find.widgetWithText(AppBar, 'Reservas de cupo'), findsNothing);
      expect(find.text('Hola, Juan'), findsOneWidget);
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
