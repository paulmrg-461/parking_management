import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/error/failure.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user.dart';
import 'auth_remote_data_source.dart';
import 'models/user_dto.dart';

/// GoTrue keeps credentials; the kiosk still asks for username + PIN, mapped
/// to `<username>@parking.local` and the PIN as the password.
String supabaseEmailFor(String username) {
  // Drop anything after '@' so a caller can never choose a different domain.
  final local = username.trim().toLowerCase().split('@').first;
  return '$local@parking.local';
}

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AuthSession> login(String username, String pin) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: supabaseEmailFor(username),
        password: pin,
      );
      final authUser = response.user;
      final token = response.session?.accessToken;
      if (authUser == null || token == null || token.isEmpty) {
        throw const AuthenticationFailure('Invalid credentials');
      }
      return AuthSession(user: await _profile(authUser), token: token);
    } on supabase.AuthException catch (error) {
      throw _failure(error);
    }
  }

  /// `public.users` is the app profile; the auth trigger creates it. If the
  /// trigger has not run yet, fall back to the JWT's app metadata.
  Future<User> _profile(supabase.User authUser) async {
    try {
      final row = await _client
          .from('users')
          .select('id, username, display_name, role, is_active')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (row != null) {
        return UserDto.fromJson(row).toDomain();
      }
    } on supabase.PostgrestException {
      // Profile lookup must never block a valid login.
    }
    final email = authUser.email ?? '';
    final username = email.contains('@') ? email.split('@').first : email;
    final role = authUser.appMetadata['role'] == 'admin'
        ? UserRole.admin
        : UserRole.operator;
    return User(
      username: username,
      displayName: username,
      role: role,
    );
  }

  Failure _failure(supabase.AuthException error) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429) {
      return RateLimitedFailure(error.message);
    }
    if (status != null && status >= 500) {
      return ServerFailure(error.message);
    }
    return AuthenticationFailure(error.message, error.code);
  }
}
