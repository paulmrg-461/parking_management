import '../../../core/storage/session_cache_cleaner.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_local_data_source.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._local, [
    this._caches,
    this._signOut,
  ]);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final SessionCacheCleaner? _caches;
  final Future<void> Function()? _signOut;

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
    // Drop the SDK's own persisted session too; otherwise the next cold
    // start would auto-restore it while the app shows the login screen.
    await _signOut?.call();
  }

  @override
  Future<AuthSession?> restoreSession() => _local.readSession();
}
