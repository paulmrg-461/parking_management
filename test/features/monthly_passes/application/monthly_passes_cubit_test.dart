import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/create_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/update_monthly_pass_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_monthly_pass_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';

final _pass = samplePass;

void main() {
  late FakeMonthlyPassRepository repository;
  late FakeVehicleRepository vehicles;
  late MonthlyPassesCubit cubit;

  setUp(() {
    repository = FakeMonthlyPassRepository();
    vehicles = FakeVehicleRepository(const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
    ]);
    cubit = MonthlyPassesCubit(repository, vehicles);
  });

  tearDown(() => cubit.close());

  MonthlyPassesLoaded loaded() => cubit.state as MonthlyPassesLoaded;

  test('Success: load precomputes vehicleId -> plate', () async {
    await cubit.load();

    expect(loaded().monthlyPasses, [_pass]);
    expect(loaded().plateOf(_pass), 'ABC123');
    expect(loaded().vehicles, hasLength(1));
  });

  test('Success: create reloads the list and reports it', () async {
    await cubit.load();

    await cubit.create(
      CreateMonthlyPassCommand(
        vehicleId: 1,
        startDate: DateTime(2026, 2),
        endDate: DateTime(2026, 2, 28),
        amount: 90000,
      ),
    );

    expect(loaded().monthlyPasses, hasLength(2));
    expect(loaded().submission, isA<SubmissionSucceeded<Object?>>());
    expect(loaded().lastAction, MonthlyPassAction.created);
  });

  test('Failure: load failure emits failure state', () async {
    repository.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, const MonthlyPassesFailure('offline'));
  });

  test(
    'Failure: a failed create keeps the list and reports the error',
    () async {
      await cubit.load();
      repository.writeError = const ValidationFailure(
        'end_date must be after start_date',
      );

      await cubit.create(
        CreateMonthlyPassCommand(
          vehicleId: 1,
          startDate: DateTime(2026, 2, 28),
          endDate: DateTime(2026, 2),
          amount: 1,
        ),
      );

      expect(loaded().monthlyPasses, [_pass]);
      expect(
        loaded().submission,
        const SubmissionFailed('end_date must be after start_date'),
      );
    },
  );

  test('Success: collecting a pending pass payment removes it', () async {
    repository.pending = [samplePayment];
    await cubit.load();

    expect(loaded().pendingPayments, [samplePayment]);

    await cubit.registerPayment(samplePayment.id, 'cash');

    expect(repository.paid, [samplePayment.id]);
    expect(loaded().pendingPayments, isEmpty);
  });

  test('Security: unknown vehicles fall back to the id label', () async {
    vehicles.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(loaded().plateOf(_pass), 'Vehicle 1');
  });

  test('Success: toggling a pass keeps the submission idle for undo', () async {
    await cubit.load();

    await cubit.update(const UpdateMonthlyPassCommand(id: 1, active: false));

    expect(loaded().submission, const SubmissionIdle());
  });

  group('committed mutation, failed refresh', () {
    test('Failure: a refresh failure after create still reports success and keeps the list', () async {
      await cubit.load();
      repository.listError = const NetworkFailure('offline');

      await cubit.create(
        CreateMonthlyPassCommand(
          vehicleId: 1,
          startDate: DateTime(2026, 2),
          endDate: DateTime(2026, 2, 28),
          amount: 90000,
        ),
      );

      expect(loaded().submission, isA<SubmissionSucceeded<Object?>>());
      expect(loaded().lastAction, MonthlyPassAction.created);
      expect(loaded().monthlyPasses, [_pass]);
    });

    test(
      'Success: success is emitted before the lists are refreshed',
      () async {
        await cubit.load();
        final states = <MonthlyPassesState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.delete(1);
        await sub.cancel();

        final loadedStates = states.whereType<MonthlyPassesLoaded>().toList();
        final firstSuccess = loadedStates.indexWhere(
          (s) => s.submission is SubmissionSucceeded,
        );
        expect(firstSuccess, greaterThan(0));
        expect(
          loadedStates.last.submission,
          isA<SubmissionSucceeded<Object?>>(),
        );
      },
    );

    test(
      'Security: a rejected mutation is a failure, never a success',
      () async {
        await cubit.load();
        repository.writeError = const ValidationFailure('Forbidden');

        await cubit.delete(1);

        expect(loaded().submission, isA<SubmissionFailed>());
      },
    );
  });
}
