import '../../../core/error/failure.dart';
import '../domain/commands/create_user_command.dart';
import '../domain/commands/update_user_command.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_local_data_source.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<AuthSession> login(String username, String pin) async {
    final session = await _remote.login(username, pin);
    await _local.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() => _local.clearSession();

  @override
  Future<AuthSession?> restoreSession() => _local.readSession();

  @override
  Future<List<User>> listUsers() async {
    return _remote.listUsers(await _currentToken());
  }

  @override
  Future<User> createUser(CreateUserCommand command) async {
    return _remote.createUser(
      await _currentToken(),
      _toCreatePayload(command),
    );
  }

  @override
  Future<User> updateUser(UpdateUserCommand command) async {
    return _remote.updateUser(
      await _currentToken(),
      command.id,
      _toUpdatePayload(command),
    );
  }

  Future<String> _currentToken() async {
    final session = await _local.readSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }

  Map<String, dynamic> _toCreatePayload(CreateUserCommand command) => {
        'username': command.username,
        'display_name': command.displayName,
        'role': command.role.name,
        'pin': command.pin,
      };

  Map<String, dynamic> _toUpdatePayload(UpdateUserCommand command) => {
        if (command.displayName != null) 'display_name': command.displayName,
        if (command.role != null) 'role': command.role!.name,
        if (command.isActive != null) 'is_active': command.isActive,
      };
}
