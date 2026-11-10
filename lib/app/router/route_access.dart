import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/receipt/evidence_link.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';

const loginPath = '/login';
const homePath = '/';
const aboutPath = '/about';
const helpPath = '/help';
const preferencesPath = '/preferences';
const reservePath = '/reserve';

/// Operators get an ALLOWLIST (secure by default: any new route is
/// admin-only until added here). Check-in reads categories/vehicles through
/// repositories, so operators never need the management routes themselves.
/// Reservations are on the list: the front desk receives the web bookings and
/// hands the space to the customer, so it needs the board (create, cancel and
/// check-in from a hold).
const operatorRoutes = {
  homePath,
  '/check-in',
  '/check-out',
  '/notifications',
  '/history',
  '/records',
  '/reservations',
  '/shift',
  '/scan',
  '/contact',
  helpPath,
  preferencesPath,
};

/// Route the router starts on.
///
/// On web the bootstrap splash runs before the router exists and takes over
/// navigation, which resets the engine's default route to `/`; the browser URL
/// is the only place a deep link (`/reserve?lot=1`, `/evidence?…`) survives.
/// Elsewhere the engine reports the launch route itself, so home is right.
String initialRouteFrom(Uri base, {bool web = kIsWeb}) {
  if (!web) {
    return homePath;
  }
  final path = base.path.isEmpty ? homePath : _normalize(base.path);
  return base.hasQuery ? '$path?${base.query}' : path;
}

bool canAccess(UserRole role, String location) =>
    role == UserRole.admin || operatorRoutes.contains(_normalize(location));

/// Pure redirect policy for `GoRouter.redirect` (unit-testable).
String? authRedirect(AuthState auth, String location) {
  final path = _normalize(location);
  // The evidence page is public: the receipt QR carries the key (the plate).
  if (path == evidencePath ||
      path == policiesPath ||
      path == aboutPath ||
      path == reservePath) {
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
