import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/application/public_booking_cubit.dart';

import '../../../helpers/fake_public_booking_repository.dart';

void main() {
  test('Success: load exposes availability for the lot', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability();
    final cubit = PublicBookingCubit(repository);

    await cubit.load(1);

    final state = cubit.state;
    expect(state.status, PublicBookingStatus.loaded);
    expect(state.availability!.lotName, 'Parqueadero Central');
    expect(repository.lastLotId, 1);
  });

  test('Failure: an unknown lot is a load failure', () async {
    final repository = FakePublicBookingRepository();
    final cubit = PublicBookingCubit(repository);

    await cubit.load(99);

    expect(cubit.state.status, PublicBookingStatus.failure);
    expect(cubit.state.failure?.code, 'LotNotFoundError');
  });

  test('Failure: a failed availability keeps the error', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityError = const NetworkFailure('offline');
    final cubit = PublicBookingCubit(repository);

    await cubit.load(1);

    expect(cubit.state.status, PublicBookingStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());
  });

  test('Success: submit books and refreshes the availability', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability();
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);
    final calls = repository.availabilityCalls;

    await cubit.submit(
      plate: 'abc123',
      categoryId: 2,
      hours: 2,
      phone: '3001112233',
      name: 'Ana',
    );

    final state = cubit.state;
    expect(state.reservation?.id, 12);
    expect(repository.lastPlate, 'abc123');
    expect(repository.availabilityCalls, calls + 1);
  });

  test(
    'Failure: a rejected reservation keeps the form and the error',
    () async {
      final repository = FakePublicBookingRepository()
        ..availabilityToReturn = sampleAvailability()
        ..reserveError = const ValidationFailure(
          'CategoryFullError',
          'CategoryFullError',
        );
      final cubit = PublicBookingCubit(repository);
      await cubit.load(1);

      await cubit.submit(
        plate: 'ABC123',
        categoryId: 2,
        hours: 2,
        phone: '3001112233',
      );

      expect(cubit.state.reservation, isNull);
      expect(cubit.state.actionFailure?.code, 'CategoryFullError');
      expect(cubit.state.submitting, isFalse);
    },
  );

  test('Success: reset returns to the form for another reservation', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability();
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);
    await cubit.submit(
      plate: 'ABC123',
      categoryId: 2,
      hours: 1,
      phone: '3001112233',
    );

    cubit.reset();

    expect(cubit.state.reservation, isNull);
    expect(cubit.state.availability, isNotNull);
  });
}
