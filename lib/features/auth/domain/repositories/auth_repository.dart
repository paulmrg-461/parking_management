import '../commands/create_user_command.dart';
import '../commands/update_user_command.dart';
import '../entities/auth_session.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<AuthSession> login(String username, String pin);

  Future<void> logout();

  Future<AuthSession?> restoreSession();

  Future<List<User>> listUsers();

  Future<User> createUser(CreateUserCommand command);

  Future<User> updateUser(UpdateUserCommand command);
}
