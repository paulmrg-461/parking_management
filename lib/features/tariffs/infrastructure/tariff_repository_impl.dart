import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import '../domain/repositories/tariff_repository.dart';
import 'tariff_local_data_source.dart';
import 'tariff_remote_data_source.dart';

class TariffRepositoryImpl implements TariffRepository {
  TariffRepositoryImpl(this._remote, this._local, this._outbox);

  final TariffRemoteDataSource _remote;
  final TariffLocalDataSource _local;
  final SyncOutbox _outbox;

  @override
  Future<List<Tariff>> list() async {
    try {
      final tariffs = await _remote.list();
      await _local.cacheAll(tariffs);
      return tariffs;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Tariff> create(CreateTariffCommand command) async {
    return _remote.create(_toCreatePayload(command));
  }

  @override
  Future<Tariff> update(UpdateTariffCommand command) async {
    final payload = _toUpdatePayload(command);
    try {
      final updated = await _remote.update(command.id, payload);
      await _local.upsert(updated);
      return updated;
    } on NetworkFailure {
      final optimistic = await _applyUpdate(command);
      if (optimistic == null) {
        rethrow;
      }
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.tariff,
          operation: MutationOperation.update,
          entityId: command.id,
          payloadJson: jsonEncode(payload),
          enqueuedAt: DateTime.now(),
        ),
      );
      return optimistic;
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _remote.delete(id);
      await _local.remove(id);
    } on NetworkFailure {
      await _local.remove(id);
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.tariff,
          operation: MutationOperation.delete,
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Merges [command]'s patch fields onto the cached tariff client-side
  /// (mirroring the backend's patch-merge shape) so the caller can show an
  /// optimistic result while offline. Returns `null` when the tariff is not
  /// cached: category/type/amount are required and must never be invented.
  Future<Tariff?> _applyUpdate(UpdateTariffCommand command) async {
    final existing = await _cachedById(command.id);
    if (existing == null) {
      return null;
    }
    final merged = Tariff(
      id: command.id,
      categoryId: existing.categoryId,
      type: command.type ?? existing.type,
      amount: command.amount ?? existing.amount,
      startTime: command.startTime ?? existing.startTime,
      endTime: command.endTime ?? existing.endTime,
      active: command.active ?? existing.active,
    );
    await _local.upsert(merged);
    return merged;
  }

  Future<Tariff?> _cachedById(int id) async {
    for (final tariff in await _local.readAll()) {
      if (tariff.id == id) {
        return tariff;
      }
    }
    return null;
  }

  Map<String, dynamic> _toCreatePayload(CreateTariffCommand command) => {
    'category_id': command.categoryId,
    'type': command.type.name,
    'amount': command.amount,
    'start_time': command.startTime,
    'end_time': command.endTime,
  };

  Map<String, dynamic> _toUpdatePayload(UpdateTariffCommand command) => {
    if (command.type != null) 'type': command.type!.name,
    if (command.amount != null) 'amount': command.amount,
    if (command.startTime != null) 'start_time': command.startTime,
    if (command.endTime != null) 'end_time': command.endTime,
    if (command.active != null) 'active': command.active,
  };
}
