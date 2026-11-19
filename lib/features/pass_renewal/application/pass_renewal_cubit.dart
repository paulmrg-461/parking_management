import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/pass_renewal_checkout.dart';
import '../domain/entities/pass_renewal_offer.dart';
import '../domain/repositories/pass_renewal_repository.dart';

/// Four explicit states for the public renewal page.
sealed class PassRenewalState extends Equatable {
  const PassRenewalState();

  @override
  List<Object?> get props => const [];
}

final class PassRenewalInitial extends PassRenewalState {
  const PassRenewalInitial();
}

final class PassRenewalLoading extends PassRenewalState {
  const PassRenewalLoading();
}

/// Unknown token, expired offer or a paid one already consumed.
final class PassRenewalUnavailable extends PassRenewalState {
  const PassRenewalUnavailable();
}

final class PassRenewalReady extends PassRenewalState {
  const PassRenewalReady(
    this.offer, {
    this.submission = const SubmissionIdle(),
  });

  final PassRenewalOffer offer;
  final Submission submission;

  PassRenewalReady copyWith({
    PassRenewalOffer? offer,
    Submission? submission,
  }) => PassRenewalReady(
    offer ?? this.offer,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [offer, submission];
}

final class PassRenewalFailure extends PassRenewalState {
  const PassRenewalFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Drives the token-keyed renewal page: load, start the payment and poll until
/// the webhook marks the offer as paid.
class PassRenewalCubit extends ResilientCubit<PassRenewalState> {
  PassRenewalCubit(
    this._repository, {
    this.pollInterval = const Duration(seconds: 3),
    this.maxPolling = const Duration(seconds: 180),
  }) : super(const PassRenewalInitial());

  final PassRenewalRepository _repository;

  /// Test seam: production values are 3 s and 180 s.
  final Duration pollInterval;
  final Duration maxPolling;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String? _trackedToken;

  Future<void> load(String token) async {
    emit(const PassRenewalLoading());
    try {
      final offer = await _repository.load(token);
      emit(
        offer == null
            ? const PassRenewalUnavailable()
            : PassRenewalReady(offer),
      );
    } on Failure catch (failure) {
      emit(PassRenewalFailure(failure));
    }
  }

  /// Starts the gateway checkout and returns the URL through
  /// `SubmissionSucceeded<PassRenewalCheckout>`.
  Future<void> pay(String token) async {
    final current = state;
    if (current is! PassRenewalReady) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final checkout = await _repository.startPayment(token);
      emit(
        current.copyWith(
          submission: SubmissionSucceeded<PassRenewalCheckout>(checkout),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  /// Polls the offer until it is paid. Safe to call twice: the previous timer
  /// is cancelled first.
  void track(String token) {
    _cancel();
    _trackedToken = token;
    _elapsed = Duration.zero;
    unawaited(_poll(token));
    _timer = Timer.periodic(pollInterval, (_) {
      _elapsed += pollInterval;
      if (_elapsed > maxPolling) {
        _cancel();
        return;
      }
      unawaited(_poll(token));
    });
  }

  Future<void> _poll(String token) async {
    if (_trackedToken != token) {
      return;
    }
    try {
      final offer = await _repository.load(token);
      if (_trackedToken != token) {
        return;
      }
      final current = state;
      if (offer == null) {
        _cancel();
        if (current is PassRenewalReady) {
          emit(const PassRenewalUnavailable());
        }
        return;
      }
      if (current is PassRenewalReady) {
        emit(current.copyWith(offer: offer));
        if (offer.status.isPaid) {
          _cancel();
        }
        return;
      }
      if (current is PassRenewalUnavailable && offer.status.isPaid) {
        emit(PassRenewalReady(offer));
        _cancel();
      }
    } on Failure {
      // Best effort: the next tick retries; the page keeps the last state.
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
