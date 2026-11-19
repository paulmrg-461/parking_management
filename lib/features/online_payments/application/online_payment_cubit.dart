import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../../../features/evidence/domain/entities/public_evidence.dart';
import '../domain/entities/payment_intent.dart';
import '../domain/entities/payment_status.dart';
import '../domain/repositories/online_payment_repository.dart';

/// Four explicit states for the public pay panel (loading, ready, empty,
/// error), plus the polling info the panel renders.
sealed class OnlinePaymentState extends Equatable {
  const OnlinePaymentState();

  @override
  List<Object?> get props => const [];
}

final class OnlinePaymentInitial extends OnlinePaymentState {
  const OnlinePaymentInitial();
}

final class OnlinePaymentLoading extends OnlinePaymentState {
  const OnlinePaymentLoading();
}

/// Nothing to pay: the session is covered (pass) or already paid.
final class OnlinePaymentNothingDue extends OnlinePaymentState {
  const OnlinePaymentNothingDue();
}

final class OnlinePaymentReady extends OnlinePaymentState {
  const OnlinePaymentReady({
    required this.amountDue,
    this.paid = 0,
    this.graceUntil,
    this.graceMinutes = 15,
    this.status,
    this.submission = const SubmissionIdle(),
  });

  /// Desk due right now (server-computed `amount_due`).
  final int amountDue;

  /// Already paid online for this session.
  final int paid;
  final DateTime? graceUntil;
  final int graceMinutes;

  /// Last polled status (`null` before the first poll).
  final PaymentStatus? status;
  final Submission submission;

  bool get isApproved => status?.isApproved ?? false;

  OnlinePaymentReady copyWith({
    int? amountDue,
    int? paid,
    DateTime? graceUntil,
    int? graceMinutes,
    PaymentStatus? status,
    Submission? submission,
  }) => OnlinePaymentReady(
    amountDue: amountDue ?? this.amountDue,
    paid: paid ?? this.paid,
    graceUntil: graceUntil ?? this.graceUntil,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    status: status ?? this.status,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [
    amountDue,
    paid,
    graceUntil,
    graceMinutes,
    status,
    submission,
  ];
}

final class OnlinePaymentFailure extends OnlinePaymentState {
  const OnlinePaymentFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Drives the public "pay from your phone" panel: prepares the state from the
/// summary, creates the intent and polls until the gateway decides.
class OnlinePaymentCubit extends ResilientCubit<OnlinePaymentState> {
  OnlinePaymentCubit(
    this._repository, {
    this.pollInterval = const Duration(seconds: 3),
    this.maxPolling = const Duration(seconds: 180),
  }) : super(const OnlinePaymentInitial());

  final OnlinePaymentRepository _repository;

  /// Test seam: production values are 3 s and 180 s.
  final Duration pollInterval;
  final Duration maxPolling;

  Timer? _timer;
  Duration _elapsed = Duration.zero;

  /// Recomputes the panel from the public session summary. A closed session,
  /// the switch off or nothing due render the empty state.
  void prepare(PublicSessionSummary summary) {
    _cancel();
    if (!summary.isOpen || !summary.onlinePaymentsEnabled) {
      emit(const OnlinePaymentNothingDue());
      return;
    }
    if (summary.amountDue <= 0) {
      emit(const OnlinePaymentNothingDue());
      return;
    }
    emit(OnlinePaymentReady(amountDue: summary.amountDue));
  }

  /// Creates the intent and hands the checkout URL back through
  /// `SubmissionSucceeded<String>`.
  Future<void> pay({required int sessionId, required String plate}) async {
    final current = state;
    if (current is! OnlinePaymentReady) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final intent = await _repository.createIntent(
        sessionId: sessionId,
        plate: plate,
      );
      emit(
        current.copyWith(
          amountDue: intent.amount,
          graceMinutes: intent.graceMinutes,
          submission: SubmissionSucceeded<PaymentIntent>(intent),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  /// Starts polling a reference (the `pay` query parameter on return).
  void track({required String reference, required String plate}) {
    _cancel();
    _elapsed = Duration.zero;
    unawaited(_poll(reference: reference, plate: plate));
    _timer = Timer.periodic(pollInterval, (_) {
      _elapsed += pollInterval;
      if (_elapsed > maxPolling) {
        _cancel();
        return;
      }
      unawaited(_poll(reference: reference, plate: plate));
    });
  }

  Future<void> _poll({required String reference, required String plate}) async {
    try {
      final status = await _repository.status(
        reference: reference,
        plate: plate,
      );
      if (status == null) {
        return;
      }
      final current = state;
      if (current is! OnlinePaymentReady) {
        return;
      }
      emit(
        current.copyWith(
          status: status.status,
          paid: status.paidTotal,
          graceUntil: status.graceUntil,
        ),
      );
      if (status.status.isFinal) {
        _cancel();
      }
    } on Failure {
      // Best effort: the next tick retries; the panel keeps the last state.
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _cancel();
    return super.close();
  }
}
