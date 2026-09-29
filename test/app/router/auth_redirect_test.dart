import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/router/route_access.dart';
import 'package:parking_management/features/auth/application/auth_cubit.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

AuthAuthenticated _as(UserRole role) => AuthAuthenticated(
      AuthSession(
        user: User(id: 1, username: 'u', displayName: 'U', role: role),
        token: 't',
      ),
    );

const _adminOnly = [
  '/users',
  '/reports',
  '/categories',
  '/tariffs',
  '/vehicles',
  '/monthly-passes',
  '/settings',
];

void main() {
  group('authRedirect', () {
    test('Success: authenticated users reach their allowed routes', () {
      expect(authRedirect(_as(UserRole.operator), '/'), isNull);
      expect(authRedirect(_as(UserRole.operator), '/check-in'), isNull);
      expect(authRedirect(_as(UserRole.operator), '/check-out'), isNull);
      expect(authRedirect(_as(UserRole.operator), '/scan'), isNull);
      expect(authRedirect(_as(UserRole.operator), '/contact'), isNull);
      for (final route in _adminOnly) {
        expect(authRedirect(_as(UserRole.admin), route), isNull, reason: route);
      }
    });

    test('Success: an authenticated user on /login is sent home', () {
      expect(authRedirect(_as(UserRole.admin), '/login'), '/');
    });

    test('Failure: unauthenticated/loading/failed states go to /login', () {
      expect(authRedirect(const AuthUnauthenticated(), '/'), '/login');
      expect(authRedirect(const AuthInitial(), '/check-in'), '/login');
      expect(authRedirect(const AuthLoading(), '/users'), '/login');
      expect(authRedirect(const AuthFailure('x'), '/login'), isNull);
      expect(authRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });

    test('Security: operators are bounced from every admin-only route', () {
      for (final route in _adminOnly) {
        expect(authRedirect(_as(UserRole.operator), route), '/', reason: route);
        expect(authRedirect(_as(UserRole.operator), '$route/'), '/', reason: route);
        expect(authRedirect(_as(UserRole.operator), '$route/5'), '/', reason: route);
      }
    });

    test('Security: operator access is an allowlist (unknown routes denied)', () {
      expect(authRedirect(_as(UserRole.operator), '/something-new'), '/');
      expect(canAccess(UserRole.operator, '/check-in'), isTrue);
      expect(canAccess(UserRole.operator, '/check-inx'), isFalse);
    });
  });
}
