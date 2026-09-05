import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/infrastructure/category_local_data_source.dart';
import 'package:parking_management/features/categories/infrastructure/category_remote_data_source.dart';
import 'package:parking_management/features/categories/infrastructure/category_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements CategoryRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;

  @override
  Future<List<Category>> list(String token) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [Category(id: 1, name: 'carro')];
  }

  @override
  Future<Category> create(String token, String name) async =>
      Category(id: 2, name: name);

  @override
  Future<Category> update(String token, int id, String name) async =>
      Category(id: id, name: name);

  @override
  Future<void> delete(String token, int id) async {}
}

void main() {
  late Directory tempDir;
  late FakeAuthRepository auth;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('category_repo_test');
    Hive.init(tempDir.path);
    auth = FakeAuthRepository(
      sessionToRestore: const AuthSession(
        user: User(id: 1, username: 'admin', displayName: 'Admin', role: UserRole.admin),
        token: 'token-1',
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  CategoryRepositoryImpl repository(_FakeRemote remote) => CategoryRepositoryImpl(
        auth,
        remote,
        HiveCategoryLocalDataSource(),
      );

  test('list returns remote categories and caches them', () async {
    final repo = repository(_FakeRemote());

    final result = await repo.list();

    expect(result.single.name, 'carro');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveCategoryLocalDataSource();
    await CategoryRepositoryImpl(auth, _FakeRemote(), local).list();

    final offline = CategoryRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
    );

    expect((await offline.list()).single.name, 'carro');
  });

  test('create calls the remote data source', () async {
    final repo = repository(_FakeRemote());

    final created = await repo.create('bus');

    expect(created.name, 'bus');
    expect(created.id, 2);
  });
}
