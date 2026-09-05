import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_sync_outbox.dart';

class _FakeRemote implements VehicleRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;

  @override
  Future<List<Vehicle>> list(String token, {String? plate}) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
    return const [Vehicle(id: 1, plate: 'ABC123', categoryId: 1)];
  }

  @override
  Future<Vehicle> create(String token, Map<String, dynamic> payload) async {
    throw UnimplementedError();
  }

  @override
  Future<Vehicle> update(String token, int id, Map<String, dynamic> payload) async {
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
  Future<void> delete(String token, int id) async {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
  }
}

void main() {
  late Directory tempDir;
  late FakeAuthRepository auth;
  late FakeSyncOutbox outbox;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vehicle_repo_test');
    Hive.init(tempDir.path);
    auth = FakeAuthRepository(
      sessionToRestore: const AuthSession(
        user: User(id: 1, username: 'admin', displayName: 'Admin', role: UserRole.admin),
        token: 'token-1',
      ),
    );
    outbox = FakeSyncOutbox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  VehicleRepositoryImpl repository(_FakeRemote remote) => VehicleRepositoryImpl(
        auth,
        remote,
        HiveVehicleLocalDataSource(),
        outbox,
      );

  test('list returns remote vehicles and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.plate, 'ABC123');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(auth, _FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.list()).single.plate, 'ABC123');
  });

  test('findByPlate falls back to cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(auth, _FakeRemote(), local, outbox).list();

    final offline = VehicleRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
      outbox,
    );

    expect((await offline.findByPlate('ABC123'))?.plate, 'ABC123');
  });

  test(
    'update queues the mutation and returns an optimistic result on network failure',
    () async {
      final local = HiveVehicleLocalDataSource();
      await VehicleRepositoryImpl(auth, _FakeRemote(), local, outbox).list();

      final offline = VehicleRepositoryImpl(
        auth,
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
      expect(outbox.enqueued.single.entityType, 'vehicle');
      expect(outbox.enqueued.single.operation, 'update');
      expect(outbox.enqueued.single.entityId, 1);
    },
  );

  test(
    'delete removes the local cache entry and queues the mutation on network failure',
    () async {
      final local = HiveVehicleLocalDataSource();
      await VehicleRepositoryImpl(auth, _FakeRemote(), local, outbox).list();

      final offline = VehicleRepositoryImpl(
        auth,
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      await offline.delete(1);

      expect(await local.readAll(), isEmpty);
      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.single.entityType, 'vehicle');
      expect(outbox.enqueued.single.operation, 'delete');
      expect(outbox.enqueued.single.entityId, 1);
    },
  );
}
