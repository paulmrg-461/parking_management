import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/infrastructure/auth_local_data_source.dart';
import 'package:parking_management/features/auth/infrastructure/caching_auth_local_data_source.dart';

class _CountingLocal implements AuthLocalDataSource {
  _CountingLocal([this.stored]);

  AuthSession? stored;
  int reads = 0;

  @override
  Future<void> saveSession(AuthSession session) async => stored = session;

  @override
  Future<AuthSession?> readSession() async {
    reads++;
    return stored;
  }

  @override
  Future<void> clearSession() async => stored = null;
}

AuthSession _session(String value) => AuthSession(
  user: const User(
    id: 1,
    username: 'juan',
    displayName: 'Juan',
    role: UserRole.operator,
  ),
  token: value,
);

void main() {
  group('CachingAuthLocalDataSource', () {
    test(
      'Success: reads storage once and serves the token from memory',
      () async {
        final inner = _CountingLocal(_session('t1'));
        final cache = CachingAuthLocalDataSource(inner);

        expect(await cache.currentToken(), 't1');
        expect(await cache.currentToken(), 't1');
        expect(inner.reads, 1);
      },
    );

    test('Success: login (saveSession) replaces the cached token', () async {
      final cache = CachingAuthLocalDataSource(_CountingLocal());
      expect(await cache.currentToken(), isNull);

      await cache.saveSession(_session('fresh'));

      expect(await cache.currentToken(), 'fresh');
      expect((await cache.readSession())?.token, 'fresh');
    });

    test(
      'Security: logout (clearSession) invalidates the cached token',
      () async {
        final inner = _CountingLocal(_session('t1'));
        final cache = CachingAuthLocalDataSource(inner);
        await cache.currentToken();

        await cache.clearSession();

        expect(await cache.currentToken(), isNull);
        expect(inner.stored, isNull);
      },
    );
  });
}
