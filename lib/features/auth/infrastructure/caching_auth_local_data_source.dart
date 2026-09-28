import '../../../core/network/session_reader.dart';
import '../domain/entities/auth_session.dart';
import 'auth_local_data_source.dart';

/// Decorator that keeps the current session in memory so every HTTP request
/// (via `AuthInterceptor`) does not hit Hive. The cache is refreshed on
/// login (`saveSession`) and invalidated on logout (`clearSession`).
class CachingAuthLocalDataSource implements AuthLocalDataSource, SessionReader {
  CachingAuthLocalDataSource(this._inner);

  final AuthLocalDataSource _inner;
  bool _loaded = false;
  AuthSession? _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    await _inner.saveSession(session);
    _remember(session);
  }

  @override
  Future<AuthSession?> readSession() async {
    if (!_loaded) {
      _remember(await _inner.readSession());
    }
    return _session;
  }

  @override
  Future<void> clearSession() async {
    await _inner.clearSession();
    _remember(null);
  }

  @override
  Future<String?> currentToken() async => (await readSession())?.token;

  void _remember(AuthSession? session) {
    _session = session;
    _loaded = true;
  }
}
