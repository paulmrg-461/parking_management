import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/commands/create_user_command.dart';
import 'package:parking_management/features/auth/domain/commands/update_user_command.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.sessionToRestore, this.loginError});

  AuthSession? sessionToRestore;
  final Failure? loginError;
  int loginCalls = 0;

  @override
  Future<AuthSession> login(String username, String pin) async {
    loginCalls++;
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

  @override
  Future<List<User>> listUsers() async => const [];

  @override
  Future<User> createUser(CreateUserCommand command) async {
    return User(
      id: 2,
      username: command.username,
      displayName: command.displayName,
      role: command.role,
    );
  }

  @override
  Future<User> updateUser(UpdateUserCommand command) async {
    return User(
      id: command.id,
      username: 'updated',
      displayName: 'Updated',
      role: UserRole.operator,
    );
  }
}
