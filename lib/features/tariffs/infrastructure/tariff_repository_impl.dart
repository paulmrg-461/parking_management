import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import '../domain/repositories/tariff_repository.dart';
import 'tariff_local_data_source.dart';
import 'tariff_remote_data_source.dart';

class TariffRepositoryImpl implements TariffRepository {
  TariffRepositoryImpl(this._auth, this._remote, this._local, this._outbox);

  final AuthRepository _auth;
  final TariffRemoteDataSource _remote;
  final TariffLocalDataSource _local;
  final SyncOutbox _outbox;

  @override
  Future<List<Tariff>> list() async {
    final token = await _currentToken();
    try {
      final tariffs = await _remote.list(token);
      await _local.cacheAll(tariffs);
      return tariffs;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<Tariff> create(CreateTariffCommand command) async {
    return _remote.create(await _currentToken(), _toCreatePayload(command));
  }

  @override
  Future<Tariff> update(UpdateTariffCommand command) async {
    final payload = _toUpdatePayload(command);
    try {
      final updated = await _remote.update(
        await _currentToken(),
        command.id,
        payload,
      );
      await _local.upsert(updated);
      return updated;
    } on NetworkFailure {
      final optimistic = await _applyUpdate(command);
      await _outbox.enqueue(
        PendingMutation(
          entityType: 'tariff',
          operation: 'update',
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
      await _remote.delete(await _currentToken(), id);
      await _local.remove(id);
    } on NetworkFailure {
      await _local.remove(id);
      await _outbox.enqueue(
        PendingMutation(
          entityType: 'tariff',
          operation: 'delete',
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Merges [command]'s patch fields onto the cached tariff client-side
  /// (mirroring the backend's patch-merge shape) so the caller can show an
  /// optimistic result while offline.
  Future<Tariff> _applyUpdate(UpdateTariffCommand command) async {
    final cached = await _local.readAll();
    Tariff? existing;
    for (final tariff in cached) {
      if (tariff.id == command.id) {
        existing = tariff;
        break;
      }
    }
    final merged = Tariff(
      id: command.id,
      categoryId: existing?.categoryId ?? 0,
      type: command.type ?? existing?.type ?? TariffType.hourly,
      amount: command.amount ?? existing?.amount ?? 0,
      startTime: command.startTime ?? existing?.startTime,
      endTime: command.endTime ?? existing?.endTime,
      active: command.active ?? existing?.active ?? true,
    );
    await _local.upsert(merged);
    return merged;
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
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
