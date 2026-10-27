import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/reservations/application/reservations_cubit.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_reservation_repository.dart';

void main() {
  late FakeReservationRepository repository;
  late FakeCategoryRepository categories;
  late ReservationsCubit cubit;

  setUp(() {
    repository = FakeReservationRepository([sampleReservation()]);
    categories = FakeCategoryRepository(const [
      Category(id: 2, name: 'car'),
    ]);
    cubit = ReservationsCubit(repository, categories);
  });

  tearDown(() => cubit.close());

  test('Success: load exposes active reservations and categories', () async {
    await cubit.load();

    final state = cubit.state as ReservationsLoaded;
    expect(state.reservations.single.plate, 'ABC123');
    expect(state.categories.single.name, 'car');
  });

  test('Success: create normalizes the plate and refreshes the list', () async {
    await cubit.load();

    await cubit.create(
      plate: ' xyz 999 ',
      categoryId: 2,
      until: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(repository.createdPlate, 'XYZ999');
    expect(repository.createdCategoryId, 2);
    final state = cubit.state as ReservationsLoaded;
    expect(state.reservations.length, 2);
    expect(state.submission, isA<SubmissionSucceeded<Object?>>());
    expect(state.lastAction, ReservationsAction.created);
  });

  test('Failure: a full category is reported without dropping the list',
      () async {
    await cubit.load();
    repository.writeError = const ValidationFailure(
      'CategoryFullError',
      'CategoryFullError',
    );

    await cubit.create(
      plate: 'XYZ999',
      categoryId: 2,
      until: DateTime.now().add(const Duration(hours: 1)),
    );

    final state = cubit.state as ReservationsLoaded;
    expect(state.reservations.single.plate, 'ABC123');
    expect((state.submission as SubmissionFailed).failure?.code,
        'CategoryFullError');
  });

  test('Failure: an invalid plate never reaches the repository', () async {
    await cubit.load();

    await cubit.create(
      plate: '   ',
      categoryId: 2,
      until: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(repository.createdPlate, isNull);
    expect(cubit.state, isA<ReservationsLoaded>());
  });

  test('Security: cancel before load does nothing', () async {
    await cubit.cancel(1);

    expect(repository.cancelledId, isNull);
    expect(cubit.state, isA<ReservationsInitial>());
  });
}
