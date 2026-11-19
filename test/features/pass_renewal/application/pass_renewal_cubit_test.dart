import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/pass_renewal/application/pass_renewal_cubit.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_checkout.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_offer.dart';

import '../../../helpers/fake_pass_renewal_repository.dart';

const _token = 'a1234567890abcdef1234567890abcdef1234567890abcd';

void main() {
  test('Success: load emits Loading then Ready', () async {
    final repository = FakePassRenewalRepository(offer: sampleOffer());
    final cubit = PassRenewalCubit(repository);
    final states = <PassRenewalState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load(_token);
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<PassRenewalLoading>());
    expect(cubit.state, isA<PassRenewalReady>());
    expect((cubit.state as PassRenewalReady).offer.lotName, 'Parqueadero Central');
    expect(repository.lastToken, _token);
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: an unknown token emits Unavailable', () async {
    final cubit = PassRenewalCubit(FakePassRenewalRepository());
    await cubit.load(_token);
    expect(cubit.state, isA<PassRenewalUnavailable>());
    await cubit.close();
  });

  test('Failure: a load error emits Failure and retry reloads', () async {
    final repository = FakePassRenewalRepository(
      failure: const NetworkFailure('offline'),
    );
    final cubit = PassRenewalCubit(repository);
    await cubit.load(_token);
    expect(cubit.state, isA<PassRenewalFailure>());

    repository
      ..failure = null
      ..offer = sampleOffer();
    await cubit.load(_token);
    expect(cubit.state, isA<PassRenewalReady>());
    expect(repository.loadCalls, 2);
    await cubit.close();
  });

  test('Success: pay returns the checkout url', () async {
    final cubit = PassRenewalCubit(
      FakePassRenewalRepository(offer: sampleOffer()),
    );
    await cubit.load(_token);
    await cubit.pay(_token);

    final submission = (cubit.state as PassRenewalReady).submission;
    expect(submission, isA<SubmissionSucceeded<PassRenewalCheckout>>());
    expect(
      (submission as SubmissionSucceeded<PassRenewalCheckout>)
          .result
          .checkoutUrl,
      contains('checkout.test'),
    );
    await cubit.close();
  });

  test('Failure: a refused payment keeps the offer and its retry', () async {
    final cubit = PassRenewalCubit(
      FakePassRenewalRepository(
        offer: sampleOffer(),
        paymentFailure: const ValidationFailure(
          'PaymentsNotConfiguredError',
          'PaymentsNotConfiguredError',
        ),
      ),
    );
    await cubit.load(_token);
    await cubit.pay(_token);

    final submission = (cubit.state as PassRenewalReady).submission;
    expect(submission, isA<SubmissionFailed>());
    expect((submission as SubmissionFailed).failure?.code,
        'PaymentsNotConfiguredError');
    await cubit.close();
  });

  test('Success: track stops on paid', () {
    fakeAsync((async) {
      final repository = FakePassRenewalRepository(
        offers: [
          sampleOffer(),
          sampleOffer(
            status: PassRenewalStatus.paid,
            renewalPeriodStart: DateTime(2026, 12, 1),
            renewalPeriodEnd: DateTime(2026, 12, 31),
          ),
        ],
      );
      final cubit = PassRenewalCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.load(_token);
      async.flushMicrotasks();
      cubit.track(_token);
      async.elapse(const Duration(seconds: 30));

      final ready = cubit.state as PassRenewalReady;
      expect(ready.offer.status, PassRenewalStatus.paid);
      expect(repository.loadCalls, lessThanOrEqualTo(3));
      cubit.close();
    });
  });

  test('Success: track stops after 180 s', () {
    fakeAsync((async) {
      final repository = FakePassRenewalRepository(
        offer: sampleOffer(),
      );
      final cubit = PassRenewalCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.load(_token);
      async.flushMicrotasks();
      cubit.track(_token);
      async.elapse(const Duration(seconds: 400));
      final calls = repository.loadCalls;
      expect(calls, lessThanOrEqualTo(62));
      async.elapse(const Duration(seconds: 60));
      expect(repository.loadCalls, calls);
      cubit.close();
    });
  });

  test('Success: closing cancels polling', () {
    fakeAsync((async) {
      final repository = FakePassRenewalRepository(offer: sampleOffer());
      final cubit = PassRenewalCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.load(_token);
      async.flushMicrotasks();
      cubit.track(_token);
      async.elapse(const Duration(seconds: 4));
      final calls = repository.loadCalls;
      cubit.close();
      async.elapse(const Duration(seconds: 60));
      expect(repository.loadCalls, calls);
    });
  });
}
