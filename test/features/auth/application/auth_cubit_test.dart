import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  group('AuthCubit', () {
    test('login success emits authenticated state', () async {
      final cubit = AuthCubit(FakeAuthRepository());

      await cubit.login('juan', '1234');

      expect(cubit.state, isA<AuthAuthenticated>());
      final session = (cubit.state as AuthAuthenticated).session;
      expect(session.user.username, 'juan');
    });

    test('login failure emits failure state', () async {
      final cubit = AuthCubit(
        FakeAuthRepository(loginError: const AuthenticationFailure('Invalid')),
      );

      await cubit.login('juan', '0000');

      expect(cubit.state, isA<AuthFailure>());
    });

    test('restore without session emits unauthenticated', () async {
      final cubit = AuthCubit(FakeAuthRepository(sessionToRestore: null));

      await cubit.restore();

      expect(cubit.state, isA<AuthUnauthenticated>());
    });

    test('restore with session emits authenticated and logout clears', () async {
      final repository = FakeAuthRepository(
        sessionToRestore: AuthSession(
          user: const User(
            id: 1,
            username: 'juan',
            displayName: 'Juan',
            role: UserRole.admin,
          ),
          token: 'token',
        ),
      );
      final cubit = AuthCubit(repository);

      await cubit.restore();
      expect(cubit.state, isA<AuthAuthenticated>());

      await cubit.logout();
      expect(cubit.state, isA<AuthUnauthenticated>());
    });
  });
}
