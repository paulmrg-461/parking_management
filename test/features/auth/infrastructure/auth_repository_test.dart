import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/infrastructure/auth_local_data_source.dart';
import 'package:parking_management/features/auth/infrastructure/auth_remote_data_source.dart';
import 'package:parking_management/features/auth/infrastructure/auth_repository_impl.dart';

import '../../../helpers/fake_token_store.dart';

class _FakeRemote implements AuthRemoteDataSource {
  _FakeRemote(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession> login(String username, String pin) async => _session;
}

AuthSession _session() => const AuthSession(
  user: User(
    id: 1,
    username: 'juan',
    displayName: 'Juan',
    role: UserRole.admin,
  ),
  token: 'token-1',
);

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  late FakeTokenStore tokens;

  AuthRepositoryImpl repository() {
    tokens = FakeTokenStore();
    return AuthRepositoryImpl(
      _FakeRemote(_session()),
      HiveAuthLocalDataSource(tokens),
    );
  }

  test('login persists the session and restore reads it back', () async {
    final repo = repository();

    await repo.login('juan', '1234');

    expect(await repo.restoreSession(), _session());
  });

  test('restore returns null when no session was stored', () async {
    final repo = repository();

    expect(await repo.restoreSession(), isNull);
  });

  test('logout clears the persisted session', () async {
    final repo = repository();

    await repo.login('juan', '1234');
    await repo.logout();

    expect(await repo.restoreSession(), isNull);
    expect(tokens.token, isNull);
  });

  test(
    'Security: the token lives in secure storage, never in the Hive profile',
    () async {
      final repo = repository();

      await repo.login('juan', '1234');

      final hiveSession = Hive.box<AuthSession>('auth').get('session');
      expect(hiveSession, isNotNull);
      expect(hiveSession!.user.username, 'juan');
      expect(hiveSession.token, isEmpty);
      expect(tokens.token, 'token-1');
      expect(await repo.restoreSession(), _session());
    },
  );

  test(
    'Security: a legacy plaintext token in Hive is discarded on read',
    () async {
      await Hive.openBox<AuthSession>('auth');
      await Hive.box<AuthSession>('auth').put(
        'session',
        const AuthSession(
          user: User(
            id: 1,
            username: 'juan',
            displayName: 'Juan',
            role: UserRole.admin,
          ),
          token: 'plaintext-legacy-token',
        ),
      );
      tokens = FakeTokenStore();
      final repo = AuthRepositoryImpl(
        _FakeRemote(_session()),
        HiveAuthLocalDataSource(tokens),
      );

      expect(await repo.restoreSession(), isNull);

      expect(Hive.box<AuthSession>('auth').get('session'), isNull);
    },
  );
}
