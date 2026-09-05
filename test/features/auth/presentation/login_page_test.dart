import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/presentation/login_page.dart';

import '../../../helpers/fake_auth_repository.dart';

Widget _wrap(AuthCubit cubit) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
    ],
  );
  return BlocProvider<AuthCubit>.value(
    value: cubit,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders username, pin, and sign in button', (tester) async {
    await tester.pumpWidget(_wrap(AuthCubit(FakeAuthRepository())));

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('submits credentials and calls login', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await tester.enterText(find.byType(TextField).at(0), 'juan');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
  });

  testWidgets('shows an error message on failed login', (tester) async {
    final repository = FakeAuthRepository(
      loginError: const AuthenticationFailure('Invalid credentials'),
    );
    await tester.pumpWidget(_wrap(AuthCubit(repository)));

    await tester.enterText(find.byType(TextField).at(0), 'juan');
    await tester.enterText(find.byType(TextField).at(1), '0000');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
