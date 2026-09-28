import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';

import '../../../helpers/fake_category_repository.dart';

const _car = Category(id: 1, name: 'carro');
const _moto = Category(id: 2, name: 'moto');

void main() {
  late FakeCategoryRepository repository;
  late CategoriesCubit cubit;

  setUp(() {
    repository = FakeCategoryRepository(const [_car, _moto]);
    cubit = CategoriesCubit(repository);
  });

  tearDown(() => cubit.close());

  test('Success: load then create reloads with Idle submission', () async {
    await cubit.load();
    await cubit.create('bus');

    final state = cubit.state as CategoriesLoaded;
    expect(state.categories.map((c) => c.name), ['carro', 'moto', 'bus']);
    expect(state.submission, const SubmissionIdle());
  });

  test('Failure: load failure emits failure state', () async {
    repository.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, const CategoriesFailure('offline'));
  });

  test(
    'Failure: a failed rename keeps the list and reports SubmissionFailed',
    () async {
      await cubit.load();
      repository.writeError = const ValidationFailure(
        'Category already exists',
      );

      await cubit.rename(_car, 'moto');

      expect(
        cubit.state,
        const CategoriesLoaded([
          _car,
          _moto,
        ], submission: SubmissionFailed('Category already exists')),
      );
    },
  );

  test('Security: categories without a server id are never mutated', () async {
    await cubit.load();

    await cubit.delete(const Category(name: 'local'));

    expect(cubit.state, const CategoriesLoaded([_car, _moto]));
  });
}
