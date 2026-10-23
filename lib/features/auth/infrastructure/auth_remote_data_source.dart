import '../domain/entities/auth_session.dart';

/// Credential exchange port. The only implementation is Supabase Auth
/// (`SupabaseAuthRemoteDataSource`).
abstract class AuthRemoteDataSource {
  Future<AuthSession> login(String username, String pin);
}
