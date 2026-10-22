import '../../../core/storage/session_cache_cleaner.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_local_data_source.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, [this._caches]);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final SessionCacheCleaner? _caches;

  @override
  Future<AuthSession> login(String username, String pin) async {
    final session = await _remote.login(username, pin);
    await _local.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    await _local.clearSession();
    // The next user must not see the previous one's cached vehicles,
    // categories, tariffs or branding.
    await _caches?.clear();
  }

  @override
  Future<AuthSession?> restoreSession() => _local.readSession();
}
