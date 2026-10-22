import 'package:hive_ce/hive_ce.dart';

import '../../../core/storage/token_store.dart';
import '../domain/entities/auth_session.dart';

abstract class AuthLocalDataSource {
  Future<void> saveSession(AuthSession session);

  Future<AuthSession?> readSession();

  Future<void> clearSession();
}

/// Hive holds the non-sensitive profile; the bearer token lives in
/// [TokenStore] (Keychain / Keystore / WebCrypto), never in plain text.
class HiveAuthLocalDataSource implements AuthLocalDataSource {
  HiveAuthLocalDataSource(this._tokens);

  static const _boxName = 'auth';
  static const _sessionKey = 'session';

  final TokenStore _tokens;

  /// Opens lazily on first use (returns the already-open box afterwards):
  /// a cold start must read the persisted session, not assume "signed out"
  /// because nothing opened the box yet.
  Future<Box<AuthSession>> _box() => Hive.openBox<AuthSession>(_boxName);

  @override
  Future<void> saveSession(AuthSession session) async {
    // Token first: a profile without its token is useless, and a token
    // without a profile is simply overwritten on the next login.
    await _tokens.write(session.token);
    final box = await _box();
    await box.put(
      _sessionKey,
      AuthSession(user: session.user, token: ''),
    );
  }

  @override
  Future<AuthSession?> readSession() async {
    final box = await _box();
    final stored = box.get(_sessionKey);
    if (stored == null) {
      return null;
    }
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      // Legacy install: the old version stored the token inside Hive. Drop it
      // instead of keeping a plaintext credential around.
      if (stored.token.isNotEmpty) {
        await box.delete(_sessionKey);
      }
      return null;
    }
    return AuthSession(user: stored.user, token: token);
  }

  @override
  Future<void> clearSession() async {
    final box = await _box();
    await box.delete(_sessionKey);
    await _tokens.delete();
  }
}
