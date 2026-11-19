import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_service.dart';
import 'package:parking_management/core/sync/sync_status_cubit.dart';
import 'package:parking_management/core/widgets/sync_badge.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_mutation_replayer.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_repository_impl.dart';

import '../../helpers/fake_sync_outbox.dart';
import '../../helpers/test_app.dart';

class _Online implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}

class _MemoryVehicles implements VehicleLocalDataSource {
  final Map<int, Vehicle> rows = {};

  @override
  Future<void> cacheAll(List<Vehicle> vehicles) async {
    rows
      ..clear()
      ..addEntries(
        vehicles.where((v) => v.id != null).map((v) => MapEntry(v.id!, v)),
      );
  }

  @override
  Future<List<Vehicle>> readAll() async => rows.values.toList();

  @override
  Future<void> upsert(Vehicle vehicle) async {
    if (vehicle.id != null) {
      rows[vehicle.id!] = vehicle;
    }
  }

  @override
  Future<void> remove(int id) async => rows.remove(id);
}

/// A one-row PostgREST stand-in: it enforces the version filter and reports
/// the row it has when the base is stale.
class _Server implements VehicleRemoteDataSource {
  _Server(this.row);

  Vehicle row;
  bool online = true;

  void _ensureOnline() {
    if (!online) {
      throw const NetworkFailure('offline');
    }
  }

  @override
  Future<Vehicle> update(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  }) async {
    _ensureOnline();
    if (baseVersion != null && baseVersion != row.version) {
      throw VersionConflictFailure(_json(row));
    }
    row = Vehicle(
      id: id,
      plate: row.plate,
      categoryId: (payload['category_id'] as int?) ?? row.categoryId,
      color: payload.containsKey('color')
          ? payload['color'] as String?
          : row.color,
      brand: payload.containsKey('brand')
          ? payload['brand'] as String?
          : row.brand,
      version: row.version + 1,
    );
    return row;
  }

  @override
  Future<void> delete(int id, {int? baseVersion}) async {
    _ensureOnline();
    if (baseVersion != null && baseVersion != row.version) {
      throw VersionConflictFailure(_json(row));
    }
    throw const ValidationFailure('gone', 'VehicleNotFoundError');
  }

  @override
  Future<Vehicle> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<List<Vehicle>> list({String? plate}) async {
    _ensureOnline();
    return [row];
  }

  @override
  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
    String? query,
  }) async {
    _ensureOnline();
    return PagedResult([row], total: 1);
  }

  Map<String, dynamic> _json(Vehicle vehicle) => {
    'id': vehicle.id,
    'plate': vehicle.plate,
    'category_id': vehicle.categoryId,
    'color': vehicle.color,
    'brand': vehicle.brand,
    'version': vehicle.version,
  };
}

class _Harness {
  _Harness({Vehicle? row})
    : server = _Server(
        row ??
            const Vehicle(
              id: 1,
              plate: 'ABC123',
              categoryId: 1,
              color: 'red',
              brand: 'Kia',
              version: 7,
            ),
      ) {
    service = SyncService(outbox, connectivity, [
      VehicleMutationReplayer(server, local),
    ]);
    repository = VehicleRepositoryImpl(server, local, outbox);
    status = SyncStatusCubit(
      outbox,
      service.discard,
      service.flush,
      service.resolve,
    );
  }

  final FakeSyncOutbox outbox = FakeSyncOutbox();
  final _Online connectivity = _Online();
  final _MemoryVehicles local = _MemoryVehicles();
  late final _Server server;
  late final SyncService service;
  late final VehicleRepositoryImpl repository;
  late final SyncStatusCubit status;

  Vehicle? get cached => local.rows[1];

  /// One review by another operator: a new value and a new version.
  void otherUserEdits({String? color, String? brand}) {
    server.row = Vehicle(
      id: 1,
      plate: server.row.plate,
      categoryId: server.row.categoryId,
      color: color ?? server.row.color,
      brand: brand ?? server.row.brand,
      version: server.row.version + 1,
    );
  }

  Future<void> editOffline({String? color, String? brand}) async {
    await repository.list();
    connectivity.online = false;
    server.online = false;
    await repository.update(
      UpdateVehicleCommand(id: 1, color: color, brand: brand),
    );
    connectivity.online = true;
    server.online = true;
  }

  Future<void> pumpBadge(WidgetTester tester) async {
    await tester.runAsync(status.load);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: status,
          child: Scaffold(appBar: AppBar(actions: const [SyncBadge()])),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'Success: a disjoint change merges silently and the queue empties',
    (tester) async {
      final h = _Harness();
      await h.editOffline(color: 'blue');
      expect(h.outbox.all.single.baseVersion, 7);

      h.otherUserEdits(brand: 'Sedan');
      await h.service.flush();
      // The merge rebases the entry on the new version; the next drain sends it.
      await h.service.flush();

      expect(h.outbox.all, isEmpty);
      expect(h.server.row.color, 'blue');
      expect(h.server.row.brand, 'Sedan');

      await h.pumpBadge(tester);
      expect(find.byIcon(Icons.merge_type), findsNothing);
    },
  );

  testWidgets('Success: keep mine from the dialog wins over the other edit', (
    tester,
  ) async {
    final h = _Harness();
    await h.editOffline(color: 'blue');
    h.otherUserEdits(color: 'green');
    await h.service.flush();

    await h.pumpBadge(tester);
    expect(find.byIcon(Icons.merge_type), findsOneWidget);

    await tester.tap(find.byIcon(Icons.merge_type));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra persona cambió este registro.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conflict-keep-mine')));
    await tester.pumpAndSettle();
    await h.service.flush();
    await tester.pumpAndSettle();

    expect(h.outbox.all, isEmpty);
    expect(h.server.row.color, 'blue');
    expect(h.cached?.color, 'blue');
  });

  testWidgets(
    'Success: keep theirs adopts the server row and clears the queue',
    (tester) async {
      final h = _Harness();
      await h.editOffline(color: 'blue');
      h.otherUserEdits(color: 'green');
      await h.service.flush();

      await h.pumpBadge(tester);
      await tester.tap(find.byIcon(Icons.merge_type));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otra persona cambió este registro.'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conflict-keep-theirs')));
      await tester.pumpAndSettle();

      expect(h.outbox.all, isEmpty);
      expect(h.cached?.color, 'green');
      expect(h.server.row.color, 'green');
    },
  );

  testWidgets('Security: an unresolved conflict is never replayed blindly', (
    tester,
  ) async {
    final h = _Harness();
    await h.editOffline(color: 'blue');
    h.otherUserEdits(color: 'green');
    await h.service.flush();

    // Several drains while parked must not touch the server row.
    await h.service.flush();
    await h.service.flush();

    expect(h.server.row.color, 'green');
    expect(h.outbox.all.single.needsResolution, isTrue);
    expect(h.outbox.all.single.operation, MutationOperation.update);
  });

  testWidgets('Failure: a failed replay stays queued with its base version', (
    tester,
  ) async {
    final h = _Harness();
    await h.editOffline(brand: 'Sedan');
    h.server.online = true;

    await h.service.flush();
    await h.service.flush();

    expect(h.outbox.all, isEmpty);
    expect(h.server.row.brand, 'Sedan');
  });
}
