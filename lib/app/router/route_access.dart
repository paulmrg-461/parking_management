import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';

const loginPath = '/login';
const homePath = '/';

/// Operators get an ALLOWLIST (secure by default: any new route is
/// admin-only until added here). Check-in reads categories/vehicles through
/// repositories, so operators never need the management routes themselves.
const operatorRoutes = {homePath, '/check-in', '/check-out', '/scan'};

bool canAccess(UserRole role, String location) =>
    role == UserRole.admin || operatorRoutes.contains(_normalize(location));

/// Pure redirect policy for `GoRouter.redirect` (unit-testable).
String? authRedirect(AuthState auth, String location) {
  final atLogin = _normalize(location) == loginPath;
  return switch (auth) {
    AuthAuthenticated() when atLogin => homePath,
    AuthAuthenticated(:final session)
        when !canAccess(session.user.role, location) =>
      homePath,
    AuthAuthenticated() => null,
    _ => atLogin ? null : loginPath,
  };
}

String _normalize(String location) {
  final path = Uri.parse(location).path;
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return trimmed.isEmpty ? homePath : trimmed;
}
