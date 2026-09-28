import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.sessionToRestore, this.loginError, this.gate});

  AuthSession? sessionToRestore;
  final Failure? loginError;

  /// When set, login waits for it (to observe the in-progress UI).
  final Future<void>? gate;
  int loginCalls = 0;

  @override
  Future<AuthSession> login(String username, String pin) async {
    loginCalls++;
    await gate;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    return AuthSession(
      user: User(
        id: 1,
        username: username,
        displayName: 'Test User',
        role: UserRole.operator,
      ),
      token: 'token-1',
    );
  }

  @override
  Future<void> logout() async {
    sessionToRestore = null;
  }

  @override
  Future<AuthSession?> restoreSession() async => sessionToRestore;
}
