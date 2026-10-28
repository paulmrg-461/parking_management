import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/application/spots_cubit.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';

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
}
