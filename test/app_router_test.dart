import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/app.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets('redirects unauthenticated users to the login page', (tester) async {
    final cubit = AuthCubit(FakeAuthRepository(sessionToRestore: null));
    await cubit.restore();

    await tester.pumpWidget(ParkingApp(authCubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows the home page for authenticated users', (tester) async {
    final cubit = AuthCubit(
      FakeAuthRepository(
        sessionToRestore: const AuthSession(
          user: User(
            id: 1,
            username: 'juan',
            displayName: 'Juan',
            role: UserRole.admin,
          ),
          token: 'token',
        ),
      ),
    );
    await cubit.restore();

    await tester.pumpWidget(ParkingApp(authCubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Juan'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
