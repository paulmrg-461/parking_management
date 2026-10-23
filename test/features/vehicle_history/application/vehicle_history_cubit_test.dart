import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicle_history/application/vehicle_history_cubit.dart';

import '../../../helpers/fake_vehicle_history_repository.dart';

void main() {
  test('Success: searches a normalized plate and exposes the history', () async {
    final repository = FakeVehicleHistoryRepository(
      history: sampleHistory(),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);

    await cubit.search(' abc 123 ');

    expect(cubit.state.status, VehicleHistoryStatus.loaded);
    expect(cubit.state.history?.plate, 'ABC123');
    expect(repository.lookups, ['ABC123']);
  });

  test('Failure: an unknown plate surfaces a retryable failure', () async {
    final repository = FakeVehicleHistoryRepository(
      error: const ValidationFailure('VehicleNotFoundError', 'VehicleNotFoundError'),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);

    await cubit.search('ZZZ999');

    expect(cubit.state.status, VehicleHistoryStatus.failure);
    expect(cubit.state.failure?.code, 'VehicleNotFoundError');
  });

  test('Security: an empty plate never reaches the repository', () async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);

    await cubit.search('   ');

    expect(repository.lookups, isEmpty);
    expect(cubit.state.status, VehicleHistoryStatus.failure);
  });

  test('Success: flags update the loaded history in place', () async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await cubit.search('ABC123');

    await cubit.updateFlags(blacklisted: true, notes: 'deuda pendiente');

    expect(cubit.state.history?.isBlacklisted, isTrue);
    expect(cubit.state.history?.notes, 'deuda pendiente');
    expect(repository.lastBlacklisted, isTrue);
    expect(repository.lastNotes, 'deuda pendiente');
  });

  test('Failure: a rejected flag change keeps the history', () async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory())
      ..flagsError = const ValidationFailure(
        'AdminRequiredError',
        'AdminRequiredError',
      );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await cubit.search('ABC123');

    await cubit.updateFlags(blacklisted: true);

    expect(cubit.state.status, VehicleHistoryStatus.loaded);
    expect(cubit.state.history?.isBlacklisted, isFalse);
    expect(cubit.state.failure?.code, 'AdminRequiredError');

    cubit.clearFailure();

    expect(cubit.state.failure, isNull);
    expect(cubit.state.history?.plate, 'ABC123');
  });

  test('Security: flags are never sent without a loaded vehicle', () async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);

    await cubit.updateFlags(blacklisted: true);

    expect(repository.lastBlacklisted, isNull);
    expect(cubit.state.status, VehicleHistoryStatus.initial);
  });
}
