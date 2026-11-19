import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/feedback_invite.dart';
import '../domain/repositories/feedback_repository.dart';

sealed class PublicFeedbackState extends Equatable {
  const PublicFeedbackState();

  @override
  List<Object?> get props => const [];
}

final class FeedbackLoading extends PublicFeedbackState {
  const FeedbackLoading();
}

/// The survey can be answered.
final class FeedbackReady extends PublicFeedbackState {
  const FeedbackReady(this.invite, {this.submitting = false, this.failure});

  final FeedbackInvite invite;
  final bool submitting;

  /// The last submit failed with a retryable reason; the form keeps its values.
  final Failure? failure;

  FeedbackReady copyWith({
    bool? submitting,
    Failure? failure,
    bool clearFailure = false,
  }) => FeedbackReady(
    invite,
    submitting: submitting ?? this.submitting,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [invite, submitting, failure];
}

/// The visit already has a rating.
final class FeedbackAlready extends PublicFeedbackState {
  const FeedbackAlready({this.rating});

  final int? rating;

  @override
  List<Object?> get props => [rating];
}

final class FeedbackSubmitted extends PublicFeedbackState {
  const FeedbackSubmitted(this.rating);

  final int rating;

  @override
  List<Object?> get props => [rating];
}

/// The session id is missing or the plate does not match: the link is not
/// useful, which is an informative state, not an error.
final class FeedbackInvalidLink extends PublicFeedbackState {
  const FeedbackInvalidLink();
}

/// The session is still open: the customer can rate after check-out.
final class FeedbackNotRateable extends PublicFeedbackState {
  const FeedbackNotRateable(this.invite);

  final FeedbackInvite invite;

  @override
  List<Object?> get props => [invite];
}

final class FeedbackFailure extends PublicFeedbackState {
  const FeedbackFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Public survey flow: load the invite by session + plate, then submit once.
class PublicFeedbackCubit extends ResilientCubit<PublicFeedbackState> {
  PublicFeedbackCubit(this._repository) : super(const FeedbackLoading());

  final FeedbackRepository _repository;
  int? _sessionId;
  String _plate = '';

  Future<void> load({required int? sessionId, required String? plate}) async {
    if (sessionId == null || sessionId <= 0 || (plate ?? '').trim().isEmpty) {
      emit(const FeedbackInvalidLink());
      return;
    }
    _sessionId = sessionId;
    _plate = plate!.trim();
    emit(const FeedbackLoading());
    try {
      final invite = await _repository.invite(
        sessionId: sessionId,
        plate: _plate,
      );
      if (invite == null) {
        emit(const FeedbackInvalidLink());
      } else if (invite.rated) {
        emit(FeedbackAlready(rating: invite.rating));
      } else if (!invite.rateable) {
        emit(FeedbackNotRateable(invite));
      } else {
        emit(FeedbackReady(invite));
      }
    } on Failure catch (failure) {
      emit(FeedbackFailure(failure));
    }
  }

  Future<void> submit({required int rating, String comment = ''}) async {
    final current = state;
    final sessionId = _sessionId;
    if (current is! FeedbackReady || sessionId == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearFailure: true));
    try {
      final stored = await _repository.submit(
        sessionId: sessionId,
        plate: _plate,
        rating: rating,
        comment: comment.trim(),
      );
      emit(FeedbackSubmitted(stored));
    } on Failure catch (failure) {
      if (failure.code == 'FeedbackAlreadyError') {
        emit(const FeedbackAlready());
      } else {
        emit(current.copyWith(submitting: false, failure: failure));
      }
    }
  }
}
