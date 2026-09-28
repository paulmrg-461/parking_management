import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_local_data_source.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_mutation_replayer.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';

class _FakeRemote implements VehicleRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  Map<String, dynamic>? updatePayload;
  int? deletedId;

  @override
  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
  }) async => const PagedResult([]);

  @override
  Future<Vehicle> update(int id, Map<String, dynamic> payload) async {
    if (error != null) {
      throw error!;
    }
    updatePayload = payload;
    return Vehicle(id: id, plate: 'ABC123', categoryId: 1, color: 'red');
  }

  @override
  Future<void> delete(int id) async => deletedId = id;

  @override
  Future<Vehicle> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<List<Vehicle>> list({String? plate}) async => const [];
}

class _FakeLocal implements VehicleLocalDataSource {
  final List<Vehicle> upserted = [];

  @override
  Future<void> upsert(Vehicle vehicle) async => upserted.add(vehicle);

  @override
  Future<void> cacheAll(List<Vehicle> vehicles) async {}

  @override
  Future<List<Vehicle>> readAll() async => const [];

  @override
  Future<void> remove(int id) async {}
}

PendingMutation _mutation(MutationOperation op, String? payload) =>
    PendingMutation(
      entityType: MutationEntity.vehicle,
      operation: op,
      entityId: 1,
      payloadJson: payload,
      enqueuedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('Success: update replays the patch and refreshes the cache', () async {
    final remote = _FakeRemote();
    final local = _FakeLocal();

    await VehicleMutationReplayer(
      remote,
      local,
    ).replay(_mutation(MutationOperation.update, '{"color":"red"}'));

    expect(remote.updatePayload, {'color': 'red'});
    expect(local.upserted.single.color, 'red');
  });

  test('Success: delete replays the delete', () async {
    final remote = _FakeRemote();

    await VehicleMutationReplayer(
      remote,
      _FakeLocal(),
    ).replay(_mutation(MutationOperation.delete, null));

    expect(remote.deletedId, 1);
  });

  test(
    'Failure: remote failures propagate and the cache is untouched',
    () async {
      final local = _FakeLocal();

      await expectLater(
        VehicleMutationReplayer(
          _FakeRemote(const ServerFailure()),
          local,
        ).replay(_mutation(MutationOperation.update, '{"color":"red"}')),
        throwsA(isA<ServerFailure>()),
      );
      expect(local.upserted, isEmpty);
    },
  );
}
