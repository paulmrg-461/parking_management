import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/presentation/login_page.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

Widget _wrap(AuthCubit cubit) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
    ],
  );
  return BlocProvider<BrandingCubit>.value(
    value: BrandingCubit(FakeParkingSettingsRepository()),
    child: BlocProvider<AuthCubit>.value(
      value: cubit,
      child: testRouterApp(router),
    ),
  );
}

Future<void> _fill(WidgetTester tester, String user, String pin) async {
  await tester.enterText(find.byType(TextField).at(0), user);
  await tester.enterText(find.byType(TextField).at(1), pin);
}

void main() {
  testWidgets('renders username, pin, and the Spanish sign-in button', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(AuthCubit(FakeAuthRepository())));

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
  });

  testWidgets('Success: submits credentials and calls login', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await _fill(tester, 'juan', '1234');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
  });

  testWidgets('Success: Enter on the PIN field submits (web keyboards)', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await _fill(tester, 'juan', '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
  });

  testWidgets('Failure: empty fields are validated and never sent', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 0);
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
  });

  testWidgets('Failure: a rejected login shows a localized, live error', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      loginError: const AuthenticationFailure(
        'Invalid credentials',
        'InvalidCredentialsError',
      ),
    );
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await _fill(tester, 'juan', '0000');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    final error = find.text('Usuario o PIN incorrectos');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error), isSemantics(isLiveRegion: true));
  });

  testWidgets('A11y: button shows a spinner and is disabled while signing in', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeAuthRepository(gate: gate.future);
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await _fill(tester, 'juan', '1234');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('A11y: fields expose autofill hints and meet tap targets', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(AuthCubit(FakeAuthRepository())));

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.autofillHints, contains(AutofillHints.username));
    expect(fields.last.autofillHints, contains(AutofillHints.password));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
