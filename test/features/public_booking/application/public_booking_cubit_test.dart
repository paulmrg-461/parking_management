import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/application/public_booking_cubit.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';

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
        name: 'Ana',
      );

      expect(cubit.state.reservation, isNull);
      expect(cubit.state.actionFailure?.code, 'CategoryFullError');
      expect(cubit.state.submitting, isFalse);
    },
  );

  test(
    'Success: cancelling the hold frees it and thanks the customer',
    () async {
      final repository = FakePublicBookingRepository()
        ..availabilityToReturn = sampleAvailability();
      final cubit = PublicBookingCubit(repository);
      await cubit.load(1);
      await cubit.submit(
        plate: 'ABC123',
        categoryId: 2,
        hours: 2,
        phone: '3001112233',
        name: 'Ana',
      );

      await cubit.cancel();

      expect(cubit.state.cancelled, isTrue);
      expect(cubit.state.reservation, isNull);
      expect(repository.cancelCalls, 1);
      expect(repository.lastCancelId, 12);
      expect(repository.lastCancelPlate, 'ABC123');
      expect(repository.lastCancelPhone, '3001112233');
    },
  );

  test('Failure: a rejected cancellation keeps the confirmation', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..cancelError = const ValidationFailure(
        'ReservationNotFoundError',
        'ReservationNotFoundError',
      );
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);
    await cubit.submit(
      plate: 'ABC123',
      categoryId: 2,
      hours: 2,
      phone: '3001112233',
      name: 'Ana',
    );

    await cubit.cancel();

    expect(cubit.state.cancelled, isFalse);
    expect(cubit.state.reservation, isNotNull);
    expect(cubit.state.actionFailure?.code, 'ReservationNotFoundError');
    expect(cubit.state.cancelling, isFalse);
  });

  test('Success: the lookup finds an active hold by code and mobile', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..lookupToReturn = PublicReservation(
        id: 12,
        plate: 'ABC123',
        categoryName: 'car',
        reservedUntil: DateTime(2026, 11, 10, 20),
      );
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);

    await cubit.lookup(code: 12, phone: '+57 300 111 2233');

    expect(cubit.state.lookupDone, isTrue);
    expect(cubit.state.lookupResult?.plate, 'ABC123');
    expect(repository.lastLookupId, 12);
    expect(repository.lastLookupPhone, '3001112233');
  });

  test(
    'Failure: a lookup without matches is an answer, not an error',
    () async {
      final repository = FakePublicBookingRepository()
        ..availabilityToReturn = sampleAvailability();
      final cubit = PublicBookingCubit(repository);
      await cubit.load(1);

      await cubit.lookup(code: 99, phone: '3001112233');

      expect(cubit.state.lookupDone, isTrue);
      expect(cubit.state.lookupResult, isNull);
      expect(cubit.state.lookupFailure, isNull);
    },
  );

  test('Failure: a network failure during the lookup is shown', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..lookupError = const NetworkFailure('offline');
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);

    await cubit.lookup(code: 12, phone: '3001112233');

    expect(cubit.state.lookupFailure, isA<NetworkFailure>());
    expect(cubit.state.lookupLoading, isFalse);
  });

  test('Success: cancelling from the lookup frees the found hold', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..lookupToReturn = PublicReservation(
        id: 12,
        plate: 'ABC123',
        categoryName: 'car',
        reservedUntil: DateTime(2026, 11, 10, 20),
      );
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);
    await cubit.lookup(code: 12, phone: '3001112233');

    await cubit.cancelLookup();

    expect(cubit.state.cancelled, isTrue);
    expect(repository.lastCancelId, 12);
    expect(repository.lastCancelPlate, 'ABC123');
    expect(repository.lastCancelPhone, '3001112233');
  });

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
      name: 'Ana',
    );

    cubit.reset();

    expect(cubit.state.reservation, isNull);
    expect(cubit.state.availability, isNotNull);
  });

  test(
    'Success: submit forwards the captcha token to the repository',
    () async {
      final repository = FakePublicBookingRepository()
        ..availabilityToReturn = sampleAvailability();
      final cubit = PublicBookingCubit(repository);
      await cubit.load(1);

      await cubit.submit(
        plate: 'ABC123',
        categoryId: 2,
        hours: 2,
        phone: '3001112233',
        name: 'Ana',
        captchaToken: 'token-1',
      );

      expect(cubit.state.reservation?.id, 12);
      expect(repository.lastCaptchaToken, 'token-1');
    },
  );

  test('Failure: a throttled lot keeps the form with a typed error', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..reserveError = const ValidationFailure(
        'BookingThrottledError',
        'BookingThrottledError',
      );
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);

    await cubit.submit(
      plate: 'ABC123',
      categoryId: 2,
      hours: 2,
      phone: '3001112233',
      name: 'Ana',
    );

    expect(cubit.state.reservation, isNull);
    expect(cubit.state.actionFailure?.code, 'BookingThrottledError');
    expect(cubit.state.submitting, isFalse);
  });

  test('Security: a rejected captcha never confirms a hold', () async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..reserveError = const ValidationFailure(
        'CaptchaFailedError',
        'CaptchaFailedError',
      );
    final cubit = PublicBookingCubit(repository);
    await cubit.load(1);

    await cubit.submit(
      plate: 'ABC123',
      categoryId: 2,
      hours: 2,
      phone: '3001112233',
      name: 'Ana',
      captchaToken: 'forged',
    );

    expect(cubit.state.reservation, isNull);
    expect(cubit.state.actionFailure?.code, 'CaptchaFailedError');
    expect(repository.lastCaptchaToken, 'forged');
  });
}
