import '../domain/entities/auth_session.dart';
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
}
