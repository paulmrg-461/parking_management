import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/di/auth_state_sync.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/infrastructure/auth_local_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _MemoryAuthLocal implements AuthLocalDataSource {
  _MemoryAuthLocal([this.session]);

  AuthSession? session;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<void> saveSession(AuthSession value) async => session = value;
}

const _user = User(
  id: 1,
  username: 'op',
  displayName: 'Operator',
  role: UserRole.operator,
);

const _persisted = AuthSession(user: _user, token: 'old-token');

sb.Session _sdkSession(String token) => sb.Session(
  accessToken: token,
  tokenType: 'bearer',
  user: const sb.User(
    id: 'uid',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

void main() {
  test('Success: a refreshed token rewrites the persisted session', () async {
    final local = _MemoryAuthLocal(_persisted);
    final sync = AuthStateSync(local, () async => fail('not expired'));

    await sync.handle(
      sb.AuthState(sb.AuthChangeEvent.tokenRefreshed, _sdkSession('new')),
    );

    expect(local.session?.token, 'new');
    expect(local.session?.user, _user);
  });

  test(
    'Failure: GoTrue signing out a persisted session reports it expired',
    () async {
      var expired = 0;
      final sync = AuthStateSync(_MemoryAuthLocal(_persisted), () async {
        expired++;
      });

      await sync.handle(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));

      expect(expired, 1);
    },
  );

  test(
    'Security: a user logout (session already cleared) is not "expired"',
    () async {
      var expired = 0;
      final sync = AuthStateSync(_MemoryAuthLocal(), () async => expired++);

      await sync.handle(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));
      await sync.handle(
        sb.AuthState(sb.AuthChangeEvent.tokenRefreshed, _sdkSession('x')),
      );

      expect(expired, 0);
    },
  );
}
