import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/auth_session.dart';

abstract class AuthLocalDataSource {
  Future<void> saveSession(AuthSession session);

  Future<AuthSession?> readSession();

  Future<void> clearSession();
}

class HiveAuthLocalDataSource implements AuthLocalDataSource {
  static const _boxName = 'auth';
  static const _sessionKey = 'session';

  /// Opens lazily on first use (returns the already-open box afterwards):
  /// a cold start must read the persisted session, not assume "signed out"
  /// because nothing opened the box yet.
  Future<Box<AuthSession>> _box() => Hive.openBox<AuthSession>(_boxName);

  @override
  Future<void> saveSession(AuthSession session) async {
    final box = await _box();
    await box.put(_sessionKey, session);
  }

  @override
  Future<AuthSession?> readSession() async {
    return (await _box()).get(_sessionKey);
  }

  @override
  Future<void> clearSession() async {
    final box = await _box();
    await box.delete(_sessionKey);
  }
}
