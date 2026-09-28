import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_repository_impl.dart';

import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements VehicleRemoteDataSource {
  _FakeRemote({
    this.failWithNetwork = false,
    this.vehicles = const [Vehicle(id: 1, plate: 'ABC123', categoryId: 1)],
  });

  final bool failWithNetwork;
  final List<Vehicle> vehicles;

  @override
  Future<List<Vehicle>> list({String? plate}) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return vehicles;
  }

  @override
  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
  }) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return PagedResult(
      vehicles.skip(offset).take(limit).toList(),
      total: vehicles.length,
    );
  }

  @override
  Future<Vehicle> create(Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<Vehicle> update(int id, Map<String, dynamic> payload) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return Vehicle(
      id: id,
      plate: 'ABC123',
      categoryId: payload['category_id'] as int? ?? 1,
      color: payload['color'] as String?,
      brand: payload['brand'] as String?,
    );
  }

  @override
  Future<void> delete(int id) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
  }
}

void main() {
  late Directory tempDir;
  late FakeSyncOutbox outbox;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vehicle_repo_test');
    Hive.init(tempDir.path);
    outbox = FakeSyncOutbox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  VehicleRepositoryImpl repository(_FakeRemote remote) =>
      VehicleRepositoryImpl(remote, HiveVehicleLocalDataSource(), outbox);

  test('list returns remote vehicles and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.plate, 'ABC123');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.list()).single.plate, 'ABC123');
  });

  test('findByPlate falls back to cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.findByPlate('ABC123'))?.plate, 'ABC123');
  });

  test('update queues the mutation and returns an optimistic result on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    final result = await offline.update(
      const UpdateVehicleCommand(id: 1, color: 'blue'),
    );

    expect(result.id, 1);
    expect(result.color, 'blue');
    expect(result.plate, 'ABC123');
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.vehicle);
    expect(outbox.enqueued.single.operation, MutationOperation.update);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test('delete removes the local cache entry and queues the mutation on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(_FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await offline.delete(1);

    expect(await local.readAll(), isEmpty);
    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.vehicle);
    expect(outbox.enqueued.single.operation, MutationOperation.delete);
    expect(outbox.enqueued.single.entityId, 1);
  });

  test(
    'Success: offline findByPlate normalizes cached plates (spaces/lowercase)',
    () async {
      final local = HiveVehicleLocalDataSource();
      await VehicleRepositoryImpl(
        _FakeRemote(
          vehicles: const [Vehicle(id: 7, plate: 'abc 123', categoryId: 1)],
        ),
        local,
        outbox,
      ).list();
      final offline = VehicleRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      expect((await offline.findByPlate(' Abc123 '))?.id, 7);
    },
  );

  test('Failure: offline update of an uncached vehicle rethrows and queues nothing', () async {
    final local = HiveVehicleLocalDataSource();
    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await expectLater(
      offline.update(const UpdateVehicleCommand(id: 99, color: 'blue')),
      throwsA(isA<NetworkFailure>()),
    );
    expect(outbox.enqueued, isEmpty);
  });

  test('Security: offline update never invents a blank plate/category in the cache', () async {
    final local = HiveVehicleLocalDataSource();
    final offline = VehicleRepositoryImpl(
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    await expectLater(
      offline.update(const UpdateVehicleCommand(id: 99, color: 'blue')),
      throwsA(isA<NetworkFailure>()),
    );
    expect(await local.readAll(), isEmpty);
  });

  group('listPage', () {
    const three = [
      Vehicle(id: 1, plate: 'AAA111', categoryId: 1),
      Vehicle(id: 2, plate: 'BBB222', categoryId: 1),
      Vehicle(id: 3, plate: 'CCC333', categoryId: 1),
    ];

    test(
      'Success: returns the remote page and keeps earlier pages cached',
      () async {
        final local = HiveVehicleLocalDataSource();
        final repo = VehicleRepositoryImpl(
          _FakeRemote(vehicles: three),
          local,
          outbox,
        );

        final first = await repo.listPage(offset: 0, limit: 2);
        await repo.listPage(offset: 2, limit: 2);

        expect(first.items, three.take(2).toList());
        expect(first.total, 3);
        expect(await local.readAll(), hasLength(3));
      },
    );

    test('Failure: offline pages are sliced from the cache', () async {
      final local = HiveVehicleLocalDataSource();
      await local.cacheAll(three);
      final repo = VehicleRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      final page = await repo.listPage(offset: 2, limit: 2);

      expect(page.items.single.plate, 'CCC333');
      expect(page.total, 3);
    });

    test(
      'Security: offline total is the cache size, so paging terminates',
      () async {
        final local = HiveVehicleLocalDataSource();
        await local.cacheAll(three);
        final repo = VehicleRepositoryImpl(
          _FakeRemote(failWithNetwork: true),
          local,
          outbox,
        );

        final page = await repo.listPage(offset: 0, limit: 50);

        expect(page.hasMoreAfter(page.items.length), isFalse);
      },
    );
  });
}
