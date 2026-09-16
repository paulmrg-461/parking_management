import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/pending_photo_storage.dart';
import 'package:parking_management/core/sync/sync_service.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
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

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({this.failWithNetwork = false});

  final bool failWithNetwork;
  int createCalls = 0;
  String? lastPlate;
  List<File>? lastPhotos;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    createCalls++;
    lastPlate = plate;
    lastPhotos = photos;
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return ParkingSession(
      id: 1,
      plate: plate,
      status: ParkingSessionStatus.open,
      entryTime: DateTime(2026, 1, 1),
      photoCount: photos.length,
    );
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => throw UnimplementedError();
}

class _FakeCheckOutRepository implements CheckOutRepository {
  _FakeCheckOutRepository({this.failWithNetwork = false});

  final bool failWithNetwork;
  int checkOutCalls = 0;
  int? lastSessionId;
  DateTime? lastClientExitTime;

  @override
  Future<List<OpenSession>> listOpenSessions() async => throw UnimplementedError();

  @override
  Future<CheckOutReceipt> checkOut(int sessionId, {DateTime? clientExitTime}) async {
    checkOutCalls++;
    lastSessionId = sessionId;
    lastClientExitTime = clientExitTime;
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return CheckOutReceipt(
      id: sessionId,
      plate: 'ABC123',
      entryTime: DateTime(2026, 1, 1),
      exitTime: DateTime(2026, 1, 1, 2),
      amountCharged: 6000,
      ticketNumber: 'TCK-000001',
    );
  }
}

class _FakePendingPhotoStorage implements PendingPhotoStorage {
  final List<String> deletedRefs = [];

  @override
  Future<void> deleteFor(String clientRef) async {
    deletedRefs.add(clientRef);
  }

  @override
  Future<List<String>> persist({
    required String clientRef,
    required List<File> photos,
  }) async =>
      throw UnimplementedError();
}

SyncService _buildService({
  required FakeSyncOutbox outbox,
  bool online = true,
  _FakeVehicleRepository? vehicles,
  _FakeTariffRepository? tariffs,
  _FakeCategoryRepository? categories,
  _FakeCheckInRepository? checkIns,
  _FakeCheckOutRepository? checkOuts,
  _FakePendingPhotoStorage? pendingPhotos,
}) =>
    SyncService(
      outbox,
      _FakeConnectivity(online: online),
      vehicles ?? _FakeVehicleRepository(),
      tariffs ?? _FakeTariffRepository(),
      categories ?? _FakeCategoryRepository(),
      checkIns ?? _FakeCheckInRepository(),
      checkOuts ?? _FakeCheckOutRepository(),
      pendingPhotos ?? _FakePendingPhotoStorage(),
    );

void main() {
  group('SyncService.flush (vehicle/tariff/category)', () {
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
      final service = _buildService(outbox: outbox, vehicles: vehicles);

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
      final service = _buildService(outbox: outbox, vehicles: vehicles);

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
        final service = _buildService(
          outbox: outbox,
          vehicles: vehicles,
          categories: categories,
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
      final service = _buildService(outbox: outbox, online: false, vehicles: vehicles);

      await service.flush();

      expect(vehicles.updateCalls, 0);
      expect(await outbox.listPending(), hasLength(1));
    });
  });

  group('SyncService.flush (checkIn replay)', () {
    test(
      'Success: replays a queued check-in, removes it from the outbox, and cleans up its photos',
      () async {
        final outbox = FakeSyncOutbox();
        await outbox.enqueue(
          PendingMutation(
            entityType: 'checkIn',
            operation: 'create',
            entityId: null,
            payloadJson:
                '{"plate":"ABC123","photo_paths":["/tmp/a.jpg"],"client_entry_time":"2026-01-01T00:00:00.000","client_ref":"ref-1"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        final checkIns = _FakeCheckInRepository();
        final pendingPhotos = _FakePendingPhotoStorage();
        final service = _buildService(
          outbox: outbox,
          checkIns: checkIns,
          pendingPhotos: pendingPhotos,
        );

        await service.flush();

        expect(checkIns.createCalls, 1);
        expect(checkIns.lastPlate, 'ABC123');
        expect(checkIns.lastPhotos, hasLength(1));
        expect(pendingPhotos.deletedRefs, ['ref-1']);
        expect(await outbox.listPending(), isEmpty);
      },
    );

    test(
      'Failure: a still-offline check-in replay stays queued and photos are not cleaned up',
      () async {
        final outbox = FakeSyncOutbox();
        await outbox.enqueue(
          PendingMutation(
            entityType: 'checkIn',
            operation: 'create',
            entityId: null,
            payloadJson:
                '{"plate":"ABC123","photo_paths":[],"client_entry_time":"2026-01-01T00:00:00.000","client_ref":"ref-1"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        final checkIns = _FakeCheckInRepository(failWithNetwork: true);
        final pendingPhotos = _FakePendingPhotoStorage();
        final service = _buildService(
          outbox: outbox,
          checkIns: checkIns,
          pendingPhotos: pendingPhotos,
        );

        await service.flush();

        expect(checkIns.createCalls, 1);
        expect(pendingPhotos.deletedRefs, isEmpty);
        expect(await outbox.listPending(), hasLength(1));
      },
    );
  });

  group('SyncService.flush (checkOut replay)', () {
    test(
      'Success: replays a queued check-out with the original client_exit_time and removes it from the outbox',
      () async {
        final outbox = FakeSyncOutbox();
        await outbox.enqueue(
          PendingMutation(
            entityType: 'checkOut',
            operation: 'close',
            entityId: 5,
            payloadJson: '{"client_exit_time":"2026-01-01T10:00:00.000"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        final checkOuts = _FakeCheckOutRepository();
        final service = _buildService(outbox: outbox, checkOuts: checkOuts);

        await service.flush();

        expect(checkOuts.checkOutCalls, 1);
        expect(checkOuts.lastSessionId, 5);
        expect(checkOuts.lastClientExitTime, DateTime.parse('2026-01-01T10:00:00.000'));
        expect(await outbox.listPending(), isEmpty);
      },
    );

    test(
      'Failure: a still-offline check-out replay stays queued, same as existing entity types',
      () async {
        final outbox = FakeSyncOutbox();
        await outbox.enqueue(
          PendingMutation(
            entityType: 'checkOut',
            operation: 'close',
            entityId: 5,
            payloadJson: '{"client_exit_time":"2026-01-01T10:00:00.000"}',
            enqueuedAt: DateTime.now(),
          ),
        );
        final checkOuts = _FakeCheckOutRepository(failWithNetwork: true);
        final service = _buildService(outbox: outbox, checkOuts: checkOuts);

        await service.flush();

        expect(checkOuts.checkOutCalls, 1);
        expect(await outbox.listPending(), hasLength(1));
      },
    );
  });
}
