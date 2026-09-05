import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';
import 'category_local_data_source.dart';
import 'category_remote_data_source.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._auth, this._remote, this._local, this._outbox);

  final AuthRepository _auth;
  final CategoryRemoteDataSource _remote;
  final CategoryLocalDataSource _local;
  final SyncOutbox _outbox;

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
    try {
      final updated = await _remote.update(await _currentToken(), id, name);
      await _local.upsert(updated);
      return updated;
    } on NetworkFailure {
      final optimistic = Category(id: id, name: name);
      await _local.upsert(optimistic);
      await _outbox.enqueue(
        PendingMutation(
          entityType: 'category',
          operation: 'update',
          entityId: id,
          payloadJson: jsonEncode({'name': name}),
          enqueuedAt: DateTime.now(),
        ),
      );
      return optimistic;
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _remote.delete(await _currentToken(), id);
      await _local.remove(id);
    } on NetworkFailure {
      await _local.remove(id);
      await _outbox.enqueue(
        PendingMutation(
          entityType: 'category',
          operation: 'delete',
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
