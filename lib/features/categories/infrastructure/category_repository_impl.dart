import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';
import 'category_local_data_source.dart';
import 'category_remote_data_source.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._auth, this._remote, this._local);

  final AuthRepository _auth;
  final CategoryRemoteDataSource _remote;
  final CategoryLocalDataSource _local;

  @override
  Future<List<Category>> list() async {
    final token = await _currentToken();
    try {
      final categories = await _remote.list(token);
      await _local.cacheAll(categories);
      return categories;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Category> create(String name) async {
    return _remote.create(await _currentToken(), name);
  }

  @override
  Future<Category> update(int id, String name) async {
    return _remote.update(await _currentToken(), id, name);
  }

  @override
  Future<void> delete(int id) async {
    return _remote.delete(await _currentToken(), id);
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
