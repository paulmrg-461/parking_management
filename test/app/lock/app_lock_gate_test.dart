import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/lock/app_lock_gate.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/security/auto_lock_cubit.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_key_value_store.dart';
import '../../helpers/test_app.dart';

const _session = AuthSession(
  user: User(
    id: 1,
    username: 'juan',
    displayName: 'Juan',
    role: UserRole.operator,
  ),
  token: 'token',
);

Future<(AuthCubit, AutoLockCubit)> _pump(
  WidgetTester tester, {
  Failure? loginError,
}) async {
  final auth = AuthCubit(
    FakeAuthRepository(sessionToRestore: _session, loginError: loginError),
  );
  final lock = AutoLockCubit(FakeKeyValueStore());
  addTearDown(auth.close);
  addTearDown(lock.close);
  await auth.restore();
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: auth),
          BlocProvider<AutoLockCubit>.value(value: lock),
        ],
        child: AppLockGate(
          cubit: lock,
          child: const Scaffold(body: Text('app content')),
        ),
      ),
    ),
  );
  return (auth, lock);
}

void main() {
  testWidgets(
    'Success: the lock screen covers the app and the PIN unlocks it',
    (tester) async {
      final (auth, lock) = await _pump(tester);

      lock.lockNow();
      await tester.pumpAndSettle();
      expect(find.text('Sesión bloqueada'), findsOneWidget);
      expect(find.text('juan'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('lock_pin')), '123456');
      await tester.tap(find.byKey(const Key('lock_unlock')));
      await tester.pumpAndSettle();

      expect(find.text('Sesión bloqueada'), findsNothing);
      expect(find.text('app content'), findsOneWidget);
      expect(auth.state, isA<AuthAuthenticated>());
    },
  );

  testWidgets('Failure: a wrong PIN keeps the app locked', (tester) async {
    final (_, lock) = await _pump(
      tester,
      loginError: const AuthenticationFailure(
        'Invalid credentials',
        'InvalidCredentialsError',
      ),
    );
    lock.lockNow();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('lock_pin')), '000000');
    await tester.tap(find.byKey(const Key('lock_unlock')));
    await tester.pumpAndSettle();

    expect(find.text('Sesión bloqueada'), findsOneWidget);
    expect(find.text('Usuario o PIN incorrectos'), findsOneWidget);
    expect(find.textContaining('Intentos restantes'), findsOneWidget);
  });

  testWidgets('Security: signing out from the lock screen releases the UI', (
    tester,
  ) async {
    final (auth, lock) = await _pump(tester);
    lock.lockNow();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Sesión bloqueada'), findsNothing);
    expect(auth.state, isA<AuthUnauthenticated>());
  });
}
