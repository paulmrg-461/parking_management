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
  }) async {
    try {
      final page = await _remote.listPage(limit: limit, offset: offset);
      for (final vehicle in page.items) {
        await _local.upsert(vehicle);
      }
      return page;
    } on NetworkFailure {
      final cached = await _local.readAll();
      return PagedResult(
        cached.skip(offset).take(limit).toList(),
        total: cached.length,
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
          entityType: MutationEntity.vehicle,
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
          entityType: MutationEntity.vehicle,
          operation: MutationOperation.delete,
          entityId: id,
          payloadJson: null,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }

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

  Map<String, dynamic> _toCreatePayload(CreateVehicleCommand command) => {
    'plate': command.plate,
    'category_id': command.categoryId,
    'color': command.color,
    'brand': command.brand,
  };

  Map<String, dynamic> _toUpdatePayload(UpdateVehicleCommand command) => {
    if (command.categoryId != null) 'category_id': command.categoryId,
    if (command.color != null) 'color': command.color,
    if (command.brand != null) 'brand': command.brand,
  };
}
