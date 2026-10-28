import '../../core/receipt/evidence_link.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';

const loginPath = '/login';
const homePath = '/';

/// Operators get an ALLOWLIST (secure by default: any new route is
/// admin-only until added here). Check-in reads categories/vehicles through
/// repositories, so operators never need the management routes themselves.
const operatorRoutes = {
  homePath,
  '/check-in',
  '/check-out',
  '/notifications',
  '/history',
  '/records',
  '/shift',
  '/scan',
  '/contact',
};

bool canAccess(UserRole role, String location) =>
    role == UserRole.admin || operatorRoutes.contains(_normalize(location));

/// Pure redirect policy for `GoRouter.redirect` (unit-testable).
String? authRedirect(AuthState auth, String location) {
  final path = _normalize(location);
  // The evidence page is public: the receipt QR carries the key (the plate).
  if (path == evidencePath || path == policiesPath) {
    return null;
  }
  final atLogin = path == loginPath;
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
