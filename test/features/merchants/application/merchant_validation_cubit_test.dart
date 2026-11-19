import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/merchants/application/merchant_validation_cubit.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_validation_result.dart';

import '../../../helpers/fake_merchant_repository.dart';

const _token = 'abcdef0123456789abcdef0123456789abcdef0123456789';

void main() {
  test('Success: load emits Loading then Ready', () async {
    final cubit = MerchantValidationCubit(
      FakePublicMerchantRepository(portalResult: samplePortal),
    );
    final states = <MerchantValidationState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load(_token);
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<MerchantValidationLoading>());
    expect(cubit.state, isA<MerchantValidationReady>());
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: an unknown token emits InvalidLink', () async {
    final cubit = MerchantValidationCubit(FakePublicMerchantRepository());
    await cubit.load(_token);
    expect(cubit.state, isA<MerchantValidationInvalidLink>());
    await cubit.close();
  });

  test('Failure: a network error emits Failure', () async {
    final cubit = MerchantValidationCubit(
      FakePublicMerchantRepository(
        portalError: const NetworkFailure('offline'),
      ),
    );
    await cubit.load(_token);
    expect(cubit.state, isA<MerchantValidationFailure>());
    await cubit.close();
  });

  test('Success: submit registers the plate and goes to Done', () async {
    final repository = FakePublicMerchantRepository(portalResult: samplePortal);
    final cubit = MerchantValidationCubit(repository);
    await cubit.load(_token);
    await cubit.submit(pin: '123456', plate: 'ABC123');

    expect(cubit.state, isA<MerchantValidationDone>());
    expect(repository.calls.single.plate, 'ABC123');
    expect(repository.calls.single.pin, '123456');
    await cubit.close();
  });

  test('Failure: a wrong PIN keeps the form with attempts left', () async {
    final repository = FakePublicMerchantRepository(
      portalResult: samplePortal,
      result: const ValidationInvalidPin(4),
    );
    final cubit = MerchantValidationCubit(repository);
    await cubit.load(_token);
    await cubit.submit(pin: '000000', plate: 'ABC123');

    final state = cubit.state as MerchantValidationReady;
    expect(state.attemptsLeft, 4);
    expect(state.submitting, isFalse);
    await cubit.close();
  });

  test('Security: a locked merchant disables the form', () async {
    final repository = FakePublicMerchantRepository(
      portalResult: samplePortal,
      result: ValidationLocked(DateTime(2026, 11, 17, 12, 30)),
    );
    final cubit = MerchantValidationCubit(repository);
    await cubit.load(_token);
    await cubit.submit(pin: '000000', plate: 'ABC123');

    final state = cubit.state as MerchantValidationReady;
    expect(state.lockedUntil, DateTime(2026, 11, 17, 12, 30));
    await cubit.close();
  });

  test('Failure: an action error keeps the form and its retry', () async {
    final repository = FakePublicMerchantRepository(
      portalResult: samplePortal,
      error: const ValidationFailure(
        'SessionNotFoundError',
        'SessionNotFoundError',
      ),
    );
    final cubit = MerchantValidationCubit(repository);
    await cubit.load(_token);
    await cubit.submit(pin: '123456', plate: 'ZZZ999');

    final state = cubit.state as MerchantValidationReady;
    expect(state.actionFailure?.code, 'SessionNotFoundError');
    await cubit.close();
  });

  test('Success: another returns to the form', () async {
    final cubit = MerchantValidationCubit(
      FakePublicMerchantRepository(portalResult: samplePortal),
    );
    await cubit.load(_token);
    await cubit.submit(pin: '123456', plate: 'ABC123');
    cubit.another();
    expect(cubit.state, isA<MerchantValidationReady>());
    await cubit.close();
  });
}
