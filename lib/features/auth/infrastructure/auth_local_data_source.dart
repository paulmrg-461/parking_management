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

  Future<Box<AuthSession>> _box() => Hive.openBox<AuthSession>(_boxName);

  @override
  Future<void> saveSession(AuthSession session) async {
    final box = await _box();
    await box.put(_sessionKey, session);
  }

  @override
  Future<AuthSession?> readSession() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return null;
    }
    return Hive.box<AuthSession>(_boxName).get(_sessionKey);
  }

  @override
  Future<void> clearSession() async {
    final box = await _box();
    await box.delete(_sessionKey);
  }
}
