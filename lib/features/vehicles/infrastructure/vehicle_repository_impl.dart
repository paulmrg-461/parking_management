import 'dart:convert';

import '../../../core/error/failure.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/commands/create_vehicle_command.dart';
import '../domain/commands/update_vehicle_command.dart';
import '../domain/entities/vehicle.dart';
import '../domain/repositories/vehicle_repository.dart';
import 'vehicle_local_data_source.dart';
import 'vehicle_remote_data_source.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl(this._remote, this._local, this._outbox);

  final VehicleRemoteDataSource _remote;
  final VehicleLocalDataSource _local;
  final SyncOutbox _outbox;

  @override
  Future<List<Vehicle>> list() async {
    try {
      final vehicles = await _remote.list();
      await _local.cacheAll(vehicles);
      return vehicles;
    } on NetworkFailure {
      return _local.readAll();
    }
  }

  @override
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
    String? query,
  }) async {
    try {
      final page = await _remote.listPage(
        limit: limit,
        offset: offset,
        query: query,
      );
      for (final vehicle in page.items) {
        await _local.upsert(vehicle);
      }
      return page;
    } on NetworkFailure {
      final cached = await _local.readAll();
      final term = query?.trim().toUpperCase() ?? '';
      final filtered = term.isEmpty
          ? cached
          : [
              for (final vehicle in cached)
                if (vehicle.plate.toUpperCase().contains(term) ||
                    (vehicle.ownerName ?? '').toUpperCase().contains(term) ||
                    (vehicle.ownerPhone ?? '').contains(term))
                  vehicle,
            ];
      return PagedResult(
        filtered.skip(offset).take(limit).toList(),
        total: filtered.length,
      );
    }
  }

  @override
  Future<Vehicle?> findByPlate(String plate) async {
    try {
      final vehicles = await _remote.list(plate: plate);
      return vehicles.isNotEmpty ? vehicles.first : null;
    } on NetworkFailure {
      return _searchCache(plate);
    }
  }

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async {
    return _remote.create(_toCreatePayload(command));
  }

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async {
    final payload = _toUpdatePayload(command);
    final cached = await _cachedById(command.id);
    await _guardPendingConflict(command.id);
    final base = command.baseVersion ?? cached?.version;
    try {
      final updated = await _remote.update(
        command.id,
        payload,
        baseVersion: (base ?? 0) > 0 ? base : null,
      );
      await _local.upsert(updated);
      return updated;
    } on VersionConflictFailure catch (failure) {
      await _parkConflict(command.id, payload, cached, failure);
      rethrow;
    } on NetworkFailure {
      final optimistic = await _applyUpdate(command);
      if (optimistic == null) {
        rethrow;
      }
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.vehicle,
          operation: MutationOperation.update,
          entityId: command.id,
          payloadJson: jsonEncode(payload),
          enqueuedAt: DateTime.now(),
          baseVersion: (base ?? 0) > 0 ? base : null,
          baseSnapshotJson: cached == null ? null : jsonEncode(_toRow(cached)),
        ),
      );
      return optimistic;
    }
  }

  @override
  Future<void> delete(int id) async {
    final cached = await _cachedById(id);
    await _guardPendingConflict(id);
    final base = cached?.version;
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
          entityType: MutationEntity.vehicle,
          operation: MutationOperation.delete,
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
          baseVersion: (base ?? 0) > 0 ? base : null,
          baseSnapshotJson: cached == null ? null : jsonEncode(_toRow(cached)),
        ),
      );
    }
  }

  /// A row with an unresolved conflict refuses new edits: they would pile up
  /// behind the same stale base.
  Future<void> _guardPendingConflict(int id) async {
    final conflicts = await _outbox.listConflicts();
    if (conflicts.any(
      (entry) =>
          entry.value.entityType == MutationEntity.vehicle &&
          entry.value.entityId == id,
    )) {
      throw const ValidationFailure(
        'Conflict pending',
        ClientFailureCodes.conflictPending,
      );
    }
  }

  /// Keeps an online conflict in the queue so the operator can resolve it
  /// from the same dialog as an offline one.
  Future<void> _parkConflict(
    int id,
    Map<String, dynamic>? payload,
    Vehicle? cached,
    VersionConflictFailure failure,
  ) async {
    final entry = PendingMutation(
      entityType: MutationEntity.vehicle,
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

  /// The cached row as the server returns it (column names), for the merge.
  Map<String, dynamic> _toRow(Vehicle vehicle) => {
    'id': vehicle.id,
    'plate': vehicle.plate,
    'category_id': vehicle.categoryId,
    'color': vehicle.color,
    'brand': vehicle.brand,
    'owner_phone': vehicle.ownerPhone,
    'owner_name': vehicle.ownerName,
    'version': vehicle.version,
  };

  /// Merges [command]'s patch fields onto the cached vehicle client-side
  /// (mirroring the backend's patch-merge shape) so the caller can show an
  /// optimistic result while offline. Returns `null` when the vehicle is not
  /// cached: plate/category are required and must never be invented.
  Future<Vehicle?> _applyUpdate(UpdateVehicleCommand command) async {
    final existing = await _cachedById(command.id);
    if (existing == null) {
      return null;
    }
    final merged = Vehicle(
      id: command.id,
      plate: existing.plate,
      categoryId: command.categoryId ?? existing.categoryId,
      color: command.color ?? existing.color,
      brand: command.brand ?? existing.brand,
      ownerPhone: _mergeOptional(command.ownerPhone, existing.ownerPhone),
      ownerName: _mergeOptional(command.ownerName, existing.ownerName),
      version: existing.version,
    );
    await _local.upsert(merged);
    return merged;
  }

  Future<Vehicle?> _cachedById(int id) async {
    for (final vehicle in await _local.readAll()) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }

  Future<Vehicle?> _searchCache(String plate) async {
    final normalized = _normalize(plate);
    for (final vehicle in await _local.readAll()) {
      if (_normalize(vehicle.plate) == normalized) {
        return vehicle;
      }
    }
    return null;
  }

  String _normalize(String plate) =>
      plate.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// `null` keeps [current]; an empty string clears the optional field.
  String? _mergeOptional(String? patch, String? current) {
    if (patch == null) {
      return current;
    }
    final value = patch.trim();
    return value.isEmpty ? null : value;
  }

  /// Same rule as [_mergeOptional], for the JSON payload: `null` is omitted
  /// (keep) and an empty string becomes JSON `null` (clear).
  String? _optionalPatch(String? patch) {
    if (patch == null) {
      return null;
    }
    final value = patch.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> _toCreatePayload(CreateVehicleCommand command) => {
    'plate': command.plate,
    'category_id': command.categoryId,
    'color': command.color,
    'brand': command.brand,
    'owner_phone': _optionalPatch(command.ownerPhone),
    'owner_name': _optionalPatch(command.ownerName),
  };

  Map<String, dynamic> _toUpdatePayload(UpdateVehicleCommand command) => {
    if (command.categoryId != null) 'category_id': command.categoryId,
    if (command.color != null) 'color': command.color,
    if (command.brand != null) 'brand': command.brand,
    if (command.ownerPhone != null)
      'owner_phone': _optionalPatch(command.ownerPhone),
    if (command.ownerName != null)
      'owner_name': _optionalPatch(command.ownerName),
  };
}
