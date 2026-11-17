import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';
import 'package:parking_management/features/online_payments/application/online_payment_cubit.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_intent.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_status.dart';
import 'package:parking_management/features/online_payments/domain/repositories/online_payment_repository.dart';

class FakeOnlinePaymentRepository implements OnlinePaymentRepository {
  FakeOnlinePaymentRepository({
    this.intent,
    this.failure,
    this.statuses = const [],
  });

  PaymentIntent? intent;
  Failure? failure;
  List<PaymentIntentStatus> statuses;
  int intentCalls = 0;
  int statusCalls = 0;

  @override
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  }) async {
    intentCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return intent ??
        PaymentIntent(
          intentId: 9,
          reference: 'PM-1A2B3C4D5E6F',
          amount: 6000,
          currency: 'COP',
          checkoutUrl: 'https://checkout.test/p/?reference=PM-1A2B3C4D5E6F',
          expiresAt: DateTime(2026, 11, 17, 12, 30),
        );
  }

  @override
  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  }) async {
    statusCalls++;
    if (statuses.isEmpty) {
      return null;
    }
    return statuses.length == 1 ? statuses.first : statuses.removeAt(0);
  }
}

PublicSessionSummary _summary({int amountDue = 6000, bool enabled = true}) =>
    PublicSessionSummary(
      sessionId: 55,
      status: 'open',
      durationSeconds: 3600,
      currency: 'COP',
      amount: amountDue,
      onlinePaymentsEnabled: enabled,
      amountDue: amountDue,
    );

PaymentIntentStatus _status(PaymentStatus status) => PaymentIntentStatus(
  status: status,
  amount: 6000,
  sessionId: 55,
  paidTotal: status.isApproved ? 6000 : 0,
  graceUntil: status.isApproved ? DateTime(2026, 11, 17, 13) : null,
);

void main() {
  test('Success: prepare with amountDue 0 emits NothingDue', () {
    final cubit = OnlinePaymentCubit(FakeOnlinePaymentRepository());
    cubit.prepare(_summary(amountDue: 0));
    expect(cubit.state, isA<OnlinePaymentNothingDue>());
  });

  test('Security: a lot with the switch off never shows the panel', () {
    final cubit = OnlinePaymentCubit(FakeOnlinePaymentRepository());
    cubit.prepare(_summary(enabled: false));
    expect(cubit.state, isA<OnlinePaymentNothingDue>());
  });

  test('Success: pay emits in progress then the checkout url', () async {
    final repository = FakeOnlinePaymentRepository();
    final cubit = OnlinePaymentCubit(repository);
    cubit.prepare(_summary());
    final states = <OnlinePaymentState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.pay(sessionId: 55, plate: 'ABC123');
    await Future<void>.delayed(Duration.zero);

    final ready = states.whereType<OnlinePaymentReady>().last;
    expect(ready.submission, isA<SubmissionSucceeded<PaymentIntent>>());
    expect(
      (ready.submission as SubmissionSucceeded<PaymentIntent>)
          .result
          .checkoutUrl,
      contains('PM-1A2B3C4D5E6F'),
    );
    expect(
      states.whereType<OnlinePaymentReady>().first.submission,
      isA<SubmissionInProgress>(),
    );
    expect(repository.intentCalls, 1);
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: a refused intent keeps the panel and its retry', () async {
    final repository = FakeOnlinePaymentRepository(
      failure: const ValidationFailure(
        'PaymentsNotConfiguredError',
        'PaymentsNotConfiguredError',
      ),
    );
    final cubit = OnlinePaymentCubit(repository);
    cubit.prepare(_summary());

    await cubit.pay(sessionId: 55, plate: 'ABC123');

    final ready = cubit.state as OnlinePaymentReady;
    expect(ready.submission, isA<SubmissionFailed>());
    expect(
      (ready.submission as SubmissionFailed).failure?.code,
      'PaymentsNotConfiguredError',
    );
    await cubit.close();
  });

  test('Success: track stops on approved', () {
    fakeAsync((async) {
      final repository = FakeOnlinePaymentRepository(
        statuses: [_status(PaymentStatus.approved)],
      );
      final cubit = OnlinePaymentCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.prepare(_summary());
      cubit.track(reference: 'PM-1A2B3C4D5E6F', plate: 'ABC123');
      async.elapse(const Duration(seconds: 30));

      final ready = cubit.state as OnlinePaymentReady;
      expect(ready.status, PaymentStatus.approved);
      expect(ready.isApproved, isTrue);
      expect(repository.statusCalls, 1);
      cubit.close();
    });
  });

  test('Success: track stops after the 180 s window', () {
    fakeAsync((async) {
      final repository = FakeOnlinePaymentRepository(
        statuses: List.generate(200, (_) => _status(PaymentStatus.pending)),
      );
      final cubit = OnlinePaymentCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.prepare(_summary());
      cubit.track(reference: 'PM-1A2B3C4D5E6F', plate: 'ABC123');
      async.elapse(const Duration(seconds: 400));
      final callsAfterWindow = repository.statusCalls;
      expect(callsAfterWindow, lessThanOrEqualTo(61));
      async.elapse(const Duration(seconds: 60));
      expect(repository.statusCalls, callsAfterWindow);
      cubit.close();
    });
  });

  test('Success: close cancels the polling timer', () {
    fakeAsync((async) {
      final repository = FakeOnlinePaymentRepository(
        statuses: List.generate(200, (_) => _status(PaymentStatus.pending)),
      );
      final cubit = OnlinePaymentCubit(
        repository,
        pollInterval: const Duration(seconds: 3),
      );
      cubit.prepare(_summary());
      cubit.track(reference: 'PM-1A2B3C4D5E6F', plate: 'ABC123');
      async.elapse(const Duration(seconds: 4));
      final calls = repository.statusCalls;
      cubit.close();
      async.elapse(const Duration(seconds: 60));
      expect(repository.statusCalls, calls);
    });
  });

  test('Failure: an unknown reference keeps the panel on pending', () async {
    final repository = FakeOnlinePaymentRepository();
    final cubit = OnlinePaymentCubit(repository);
    cubit.prepare(_summary());
    cubit.track(reference: 'PM-UNKNOWN', plate: 'ABC123');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<OnlinePaymentReady>());
    await cubit.close();
  });
}
