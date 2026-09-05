import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/create_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/commands/update_monthly_pass_command.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/domain/repositories/monthly_pass_repository.dart';

class _FakeRepository implements MonthlyPassRepository {
  _FakeRepository({this.listError, this.createError});

  final Failure? listError;
  final Failure? createError;

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
    if (listError != null) {
      throw listError!;
    }
    return [
      MonthlyPass(
        id: 1,
        vehicleId: 1,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        amount: 100000,
      ),
    ];
  }

  @override
  Future<MonthlyPass> create(CreateMonthlyPassCommand command) async {
    final error = createError;
    if (error != null) {
      throw error;
    }
    return MonthlyPass(
      id: 2,
      vehicleId: command.vehicleId,
      startDate: command.startDate,
      endDate: command.endDate,
      amount: command.amount,
    );
  }

  @override
  Future<MonthlyPass> update(UpdateMonthlyPassCommand command) async =>
      MonthlyPass(
        id: 1,
        vehicleId: 1,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        amount: 100000,
      );

  @override
  Future<void> delete(int id) async {}
}

void main() {
  test('Success: load emits loaded state with monthly passes', () async {
    final cubit = MonthlyPassesCubit(_FakeRepository());

    await cubit.load();

    expect(cubit.state, isA<MonthlyPassesLoaded>());
    expect(
      (cubit.state as MonthlyPassesLoaded).monthlyPasses.single.amount,
      100000,
    );
  });

  test('Failure: load emits failure state when the repository throws NetworkFailure', () async {
    final cubit = MonthlyPassesCubit(
      _FakeRepository(listError: const NetworkFailure('offline')),
    );

    await cubit.load();

    expect(cubit.state, isA<MonthlyPassesFailure>());
    expect((cubit.state as MonthlyPassesFailure).message, 'offline');
  });

  test(
    'Security: create with invalid dates rejected by the repository maps to a failure state, not a crash',
    () async {
      final cubit = MonthlyPassesCubit(
        _FakeRepository(createError: const ValidationFailure('end_date must be after start_date')),
      );

      await cubit.create(
        CreateMonthlyPassCommand(
          vehicleId: 1,
          startDate: DateTime(2026, 2, 1),
          endDate: DateTime(2026, 1, 1),
          amount: 100000,
        ),
      );

      expect(cubit.state, isA<MonthlyPassesFailure>());
      expect(
        (cubit.state as MonthlyPassesFailure).message,
        'end_date must be after start_date',
      );
    },
  );
}
