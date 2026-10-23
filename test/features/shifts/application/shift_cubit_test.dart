import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/shifts/application/shift_cubit.dart';

import '../../../helpers/fake_shift_repository.dart';

void main() {
  test('Success: opens a shift and exposes its totals', () async {
    final repository = FakeShiftRepository();
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.open(20000);

    expect(cubit.state.current, isNotNull);
    expect(cubit.state.current?.openingFloat, 20000);
    expect(cubit.state.current?.expectedCash, 25000);
  });

  test('Success: closing stores the lastClosed summary', () async {
    final repository = FakeShiftRepository(currentShift: sampleShift());
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.closeShift(countedCash: 15000, notes: 'ok');

    expect(cubit.state.current, isNull);
    expect(cubit.state.lastClosed?.countedCash, 15000);
    expect(cubit.state.lastClosed?.notes, 'ok');
  });

  test('Failure: a backend error keeps the shift and reports it', () async {
    final repository = FakeShiftRepository(currentShift: sampleShift())
      ..error = const NetworkFailure('offline');
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, ShiftStatus.failure);
    expect(cubit.state.error, isA<NetworkFailure>());
  });

  test('Success: an admin can correct a closed shift with a reason', () async {
    final repository = FakeShiftRepository(
      historyShifts: [sampleShift(closed: true, countedCash: 15000)],
    );
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);

    await cubit.adjust(
      shiftId: 1,
      countedCash: 13900,
      reason: 'correccion',
    );

    expect(cubit.state.history.single.countedCash, 13900);
    expect(cubit.state.history.single.notes, 'correccion');
  });

  test('Security: only admins load the shift history', () async {
    final repository = FakeShiftRepository(
      historyShifts: [sampleShift(closed: true)],
    );
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.history, isEmpty);

    await cubit.load(admin: true);
    expect(cubit.state.history, hasLength(1));
  });
}
