import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login(String username, String pin);

  Future<void> logout();

  Future<AuthSession?> restoreSession();
}
