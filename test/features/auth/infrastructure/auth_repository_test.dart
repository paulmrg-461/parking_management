import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/auth/infrastructure/auth_local_data_source.dart';
import 'package:parking_management/features/auth/infrastructure/auth_remote_data_source.dart';
import 'package:parking_management/features/auth/infrastructure/auth_repository_impl.dart';

class _FakeRemote implements AuthRemoteDataSource {
  _FakeRemote(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession> login(String username, String pin) async => _session;

  @override
  Future<List<User>> listUsers(String token) async => const [];

  @override
  Future<User> createUser(String token, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<User> updateUser(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    throw UnimplementedError();
  }
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

  AuthRepositoryImpl repository() => AuthRepositoryImpl(
        _FakeRemote(_session()),
        HiveAuthLocalDataSource(),
      );

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
  });
}
