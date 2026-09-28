import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/tariffs/application/tariffs_cubit.dart';
import 'package:parking_management/features/tariffs/domain/commands/create_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/commands/update_tariff_command.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_tariff_repository.dart';

const _hourly = hourlyTariff;

void main() {
  late FakeTariffRepository repository;
  late FakeCategoryRepository categories;
  late TariffsCubit cubit;

  setUp(() {
    repository = FakeTariffRepository();
    categories = FakeCategoryRepository(const [Category(id: 1, name: 'carro')]);
    cubit = TariffsCubit(repository, categories);
  });

  tearDown(() => cubit.close());

  TariffsLoaded loaded() => cubit.state as TariffsLoaded;

  test('Success: load precomputes category names for each tariff', () async {
    await cubit.load();

    expect(loaded().tariffs, const [_hourly]);
    expect(loaded().categoryNameOf(_hourly), 'carro');
  });

  test('Success: create reloads the list', () async {
    await cubit.load();

    await cubit.create(
      const CreateTariffCommand(
        categoryId: 1,
        type: TariffType.daily,
        amount: 20000,
      ),
    );

    expect(loaded().tariffs, hasLength(2));
    expect(loaded().submission, const SubmissionIdle());
  });

  test('Failure: load failure emits failure state', () async {
    repository.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, const TariffsFailure('offline'));
  });

  test(
    'Failure: a failed toggle keeps the list and reports the error',
    () async {
      await cubit.load();
      repository.writeError = const ValidationFailure('Invalid window');

      await cubit.update(const UpdateTariffCommand(id: 1, active: false));

      expect(loaded().tariffs, const [_hourly]);
      expect(loaded().submission, const SubmissionFailed('Invalid window'));
    },
  );

  test('Security: missing categories fall back to the id label', () async {
    categories.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(loaded().categoryNameOf(_hourly), 'Category 1');
  });
}
