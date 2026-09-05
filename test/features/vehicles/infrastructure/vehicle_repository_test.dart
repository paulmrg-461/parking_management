import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

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
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String token, int id) async {}
}

void main() {
  late Directory tempDir;
  late FakeAuthRepository auth;

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
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  VehicleRepositoryImpl repository(_FakeRemote remote) => VehicleRepositoryImpl(
        auth,
        remote,
        HiveVehicleLocalDataSource(),
      );

  test('list returns remote vehicles and caches them', () async {
    final result = await repository(_FakeRemote()).list();

    expect(result.single.plate, 'ABC123');
  });

  test('list falls back to the local cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(auth, _FakeRemote(), local).list();

    final offline = VehicleRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
    );

    expect((await offline.list()).single.plate, 'ABC123');
  });

  test('findByPlate falls back to cache on network failure', () async {
    final local = HiveVehicleLocalDataSource();
    await VehicleRepositoryImpl(auth, _FakeRemote(), local).list();

    final offline = VehicleRepositoryImpl(
      auth,
      _FakeRemote(failWithNetwork: true),
      local,
    );

    expect((await offline.findByPlate('ABC123'))?.plate, 'ABC123');
  });
}
