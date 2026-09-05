import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/sync_service.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/tariffs/domain/commands/create_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/domain/repositories/tariff_repository.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

import '../../helpers/fake_sync_outbox.dart';

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.online = true});

  bool online;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeVehicleRepository implements VehicleRepository {
  _FakeVehicleRepository({this.failWithNetwork = false});

  final bool failWithNetwork;
  int updateCalls = 0;

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) async {
    updateCalls++;
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return Vehicle(id: command.id, plate: 'ABC123', categoryId: 1);
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<Vehicle> create(CreateVehicleCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Vehicle?> findByPlate(String plate) async => throw UnimplementedError();

  @override
  Future<List<Vehicle>> list() async => throw UnimplementedError();
}

class _FakeTariffRepository implements TariffRepository {
  int updateCalls = 0;

  @override
  Future<Tariff> update(UpdateTariffCommand command) async {
    updateCalls++;
    return Tariff(id: command.id, categoryId: 1, type: TariffType.hourly, amount: 1000);
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<Tariff> create(CreateTariffCommand command) async =>
      throw UnimplementedError();

  @override
  Future<List<Tariff>> list() async => throw UnimplementedError();
}

class _FakeCategoryRepository implements CategoryRepository {
  int updateCalls = 0;

  @override
  Future<Category> update(int id, String name) async {
    updateCalls++;
    return Category(id: id, name: name);
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<Category> create(String name) async => throw UnimplementedError();

  @override
  Future<List<Category>> list() async => throw UnimplementedError();
}

void main() {
  group('SyncService.flush', () {
    test('Success: replays a pending update and removes it from the outbox', () async {
      final outbox = FakeSyncOutbox();
      await outbox.enqueue(
        PendingMutation(
          entityType: 'vehicle',
          operation: 'update',
          entityId: 1,
          payloadJson: '{"color":"red"}',
          enqueuedAt: DateTime.now(),
        ),
      );
      final vehicles = _FakeVehicleRepository();
      final service = SyncService(
        outbox,
        _FakeConnectivity(online: true),
        vehicles,
        _FakeTariffRepository(),
        _FakeCategoryRepository(),
      );

      await service.flush();

      expect(vehicles.updateCalls, 1);
      expect(await outbox.listPending(), isEmpty);
    });

    test('Failure: a still-failing replay stays queued and flush does not throw', () async {
      final outbox = FakeSyncOutbox();
      await outbox.enqueue(
        PendingMutation(
          entityType: 'vehicle',
          operation: 'update',
          entityId: 1,
          payloadJson: '{"color":"red"}',
          enqueuedAt: DateTime.now(),
        ),
      );
      final vehicles = _FakeVehicleRepository(failWithNetwork: true);
      final service = SyncService(
        outbox,
        _FakeConnectivity(online: true),
        vehicles,
        _FakeTariffRepository(),
        _FakeCategoryRepository(),
      );

      await expectLater(service.flush(), completes);

      expect(vehicles.updateCalls, 1);
      expect(await outbox.listPending(), hasLength(1));
    });

    test(
      'Security/robustness: one poison entry does not block an independent second entry',
      () async {
        final outbox = FakeSyncOutbox();
        await outbox.enqueue(
          PendingMutation(
            entityType: 'vehicle',
            operation: 'update',
            entityId: 1,
            payloadJson: '{"color":"red"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        await outbox.enqueue(
          PendingMutation(
            entityType: 'category',
            operation: 'update',
            entityId: 2,
            payloadJson: '{"name":"bus"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        final vehicles = _FakeVehicleRepository(failWithNetwork: true);
        final categories = _FakeCategoryRepository();
        final service = SyncService(
          outbox,
          _FakeConnectivity(online: true),
          vehicles,
          _FakeTariffRepository(),
          categories,
        );

        await service.flush();

        expect(categories.updateCalls, 1);
        final remaining = await outbox.listPending();
        expect(remaining, hasLength(1));
        expect(remaining.single.value.entityType, 'vehicle');
      },
    );

    test('does nothing when offline', () async {
      final outbox = FakeSyncOutbox();
      await outbox.enqueue(
        PendingMutation(
          entityType: 'vehicle',
          operation: 'update',
          entityId: 1,
          payloadJson: '{"color":"red"}',
          enqueuedAt: DateTime.now(),
        ),
      );
      final vehicles = _FakeVehicleRepository();
      final service = SyncService(
        outbox,
        _FakeConnectivity(online: false),
        vehicles,
        _FakeTariffRepository(),
        _FakeCategoryRepository(),
      );

      await service.flush();

      expect(vehicles.updateCalls, 0);
      expect(await outbox.listPending(), hasLength(1));
    });
  });
}
