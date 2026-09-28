import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/create_monthly_pass_command.dart';
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

  test('Success: create reloads the list with Idle submission', () async {
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
    expect(loaded().submission, const SubmissionIdle());
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

  test('Security: unknown vehicles fall back to the id label', () async {
    vehicles.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(loaded().plateOf(_pass), 'Vehicle 1');
  });
}
