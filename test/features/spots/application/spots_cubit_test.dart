import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/application/spots_cubit.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/domain/entities/spot_event.dart';

import '../../../helpers/fake_spot_repository.dart';

void main() {
  test('Success: load keeps the map ordered by the server', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, SpotsStatus.loaded);
    expect(cubit.state.spots.single.code, 'A1');
  });

  test('Failure: adding a spot takes the first free cell', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
      ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    final spot = await cubit.add(code: 'A3', group: SlotGroup.car);

    expect(spot?.row, 0);
    expect(spot?.col, 2);
    expect(cubit.state.spots, hasLength(3));
  });

  test('Security: a failed move restores the previous map', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    repository.writeError = const NetworkFailure('offline');

    final moved = await cubit.move(cubit.state.spots.single, 5, 5);

    expect(moved, isNull);
    expect(cubit.state.spots.single.row, 0);
    expect(cubit.state.spots.single.col, 0);
    expect(cubit.state.actionError, isNotNull);
  });

  test('Failure: a taken cell is refused before calling the server', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
      ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    final moved = await cubit.move(cubit.state.spots.first, 0, 1);

    expect(moved, isNull);
    expect(cubit.state.spots.first.col, 0);
  });

  test('Failure: a group cannot exceed the configured spots', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
      ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setTargets(const {SlotGroup.car: 2});

    final added = await cubit.add(code: 'A3', group: SlotGroup.car);

    expect(added, isNull);
    expect(repository.spots, hasLength(2));
    expect(cubit.state.actionError?.code, 'SpotCapacityReachedError');
  });

  test('Security: deleting below the configured spots is refused', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
      ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setTargets(const {SlotGroup.car: 2});

    final removed = await cubit.remove(cubit.state.spots.first);

    expect(removed, isFalse);
    expect(repository.spots, hasLength(2));

    // Lowering the target in Ajustes makes the removal legal.
    cubit.setTargets(const {SlotGroup.car: 1});
    expect(await cubit.remove(cubit.state.spots.first), isTrue);
  });

  test('Success: going out of service sends the maintenance reason', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
    ]);
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.update(
      cubit.state.spots.single.copyWith(active: false),
      reason: 'fuga de aceite',
    );

    expect(repository.lastReason, 'fuga de aceite');
    expect(cubit.state.spots.single.active, isFalse);
  });

  test('Success: the maintenance history is read per bay', () async {
    final repository = FakeSpotRepository(const [
      ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
    ]);
    repository.events = [
      SpotEvent(
        id: 7,
        spotId: 1,
        spotCode: 'A1',
        active: false,
        reason: 'pintura',
        actorName: 'Paul',
        createdAt: DateTime(2026, 11, 9, 10),
      ),
      SpotEvent(
        id: 8,
        spotId: 2,
        spotCode: 'B2',
        active: true,
        createdAt: DateTime(2026, 11, 9, 11),
      ),
    ];
    final cubit = SpotsCubit(repository);
    addTearDown(cubit.close);

    final events = await cubit.listEvents(1);

    expect(repository.eventCalls, 1);
    expect(events, hasLength(1));
    expect(events.single.reason, 'pintura');
  });
}
