import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';
import 'category_local_data_source.dart';
import 'category_remote_data_source.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._remote, this._local, this._outbox);

  final CategoryRemoteDataSource _remote;
  final CategoryLocalDataSource _local;
  final SyncOutbox _outbox;

  @override
  Future<List<Category>> list() async {
    try {
      final categories = await _remote.list();
      await _local.cacheAll(categories);
      return categories;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Category> create(String name) async {
    return _remote.create(name);
  }

  @override
  Future<Category> update(int id, String name, {int? baseVersion}) =>
      _patch(id, {'name': name}, baseVersion: baseVersion);

  @override
  Future<Category> setCapacity(int id, int capacity, {int? baseVersion}) =>
      _patch(id, {'capacity': capacity}, baseVersion: baseVersion);

  Future<Category> _patch(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  }) async {
    final cached = await _cachedById(id);
    await _guardPendingConflict(id);
    final base = baseVersion ?? cached?.version;
    try {
      final updated = await _remote.patch(
        id,
        payload,
        baseVersion: (base ?? 0) > 0 ? base : null,
      );
      await _local.upsert(updated);
      return updated;
    } on VersionConflictFailure catch (failure) {
      await _parkConflict(id, payload, cached, failure);
      rethrow;
    } on NetworkFailure {
      final optimistic = Category(
        id: id,
        name: payload['name'] as String? ?? cached?.name ?? '',
        capacity: payload['capacity'] as int? ?? cached?.capacity ?? 0,
        version: cached?.version ?? 0,
      );
      await _local.upsert(optimistic);
      // Send the whole row so a name edit does not drop the capacity change
      // that was queued before it (and vice versa).
      final full = {'name': optimistic.name, 'capacity': optimistic.capacity};
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.category,
          operation: MutationOperation.update,
          entityId: id,
          payloadJson: jsonEncode(full),
          enqueuedAt: DateTime.now(),
          baseVersion: (base ?? 0) > 0 ? base : null,
          baseSnapshotJson: cached == null ? null : jsonEncode(_toRow(cached)),
        ),
      );
      return optimistic;
    }
  }

  Future<void> _guardPendingConflict(int id) async {
    final conflicts = await _outbox.listConflicts();
    if (conflicts.any(
      (entry) =>
          entry.value.entityType == MutationEntity.category &&
          entry.value.entityId == id,
    )) {
      throw const ValidationFailure(
        'Conflict pending',
        ClientFailureCodes.conflictPending,
      );
    }
  }

  Future<void> _parkConflict(
    int id,
    Map<String, dynamic>? payload,
    Category? cached,
    VersionConflictFailure failure,
  ) async {
    final entry = PendingMutation(
      entityType: MutationEntity.category,
      operation: payload == null
          ? MutationOperation.delete
          : MutationOperation.update,
      entityId: id,
      payloadJson: payload == null ? null : jsonEncode(payload),
      enqueuedAt: DateTime.now(),
      baseVersion: cached?.version,
      baseSnapshotJson: cached == null ? null : jsonEncode(_toRow(cached)),
    );
    await _outbox.enqueue(
      entry.asConflict(
        kind: failure.serverRow == null ? 'deleted' : 'edited',
        serverRow: failure.serverRow,
      ),
    );
  }

  Map<String, dynamic> _toRow(Category category) => {
    'id': category.id,
    'name': category.name,
    'capacity': category.capacity,
    'version': category.version,
  };

  Future<Category?> _cachedById(int id) async {
    for (final category in await _local.readAll()) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  @override
  Future<void> delete(int id, {int? baseVersion}) async {
    final cached = await _cachedById(id);
    await _guardPendingConflict(id);
    final base = baseVersion ?? cached?.version;
    try {
      await _remote.delete(id, baseVersion: (base ?? 0) > 0 ? base : null);
      await _local.remove(id);
    } on VersionConflictFailure catch (failure) {
      await _parkConflict(id, null, cached, failure);
      rethrow;
    } on NetworkFailure {
      await _local.remove(id);
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.category,
          operation: MutationOperation.delete,
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }
}
