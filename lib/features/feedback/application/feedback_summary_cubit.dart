import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/feedback_summary.dart';
import '../domain/repositories/feedback_repository.dart';

sealed class FeedbackSummaryState extends Equatable {
  const FeedbackSummaryState();

  @override
  List<Object?> get props => const [];
}

final class FeedbackSummaryInitial extends FeedbackSummaryState {
  const FeedbackSummaryInitial();
}

final class FeedbackSummaryLoading extends FeedbackSummaryState {
  const FeedbackSummaryLoading();
}

final class FeedbackSummaryLoaded extends FeedbackSummaryState {
  const FeedbackSummaryLoaded(
    this.summary,
    this.days, {
    this.refreshing = false,
  });

  final FeedbackSummary summary;

  /// Selected period. It changes before the new figures arrive, so the chips
  /// respond immediately while the content stays on screen.
  final int days;
  final bool refreshing;

  FeedbackSummaryLoaded copyWith({int? days, bool? refreshing}) =>
      FeedbackSummaryLoaded(
        summary,
        days ?? this.days,
        refreshing: refreshing ?? this.refreshing,
      );

  @override
  List<Object?> get props => [summary, days, refreshing];
}

final class FeedbackSummaryFailure extends FeedbackSummaryState {
  const FeedbackSummaryFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Admin satisfaction report. A period switch never flashes the skeleton; only
/// the first load does.
class FeedbackSummaryCubit extends ResilientCubit<FeedbackSummaryState> {
  FeedbackSummaryCubit(this._repository)
    : super(const FeedbackSummaryInitial());

  final FeedbackRepository _repository;

  Future<void> load([int days = 30]) async {
    final current = state;
    if (current is FeedbackSummaryLoaded) {
      emit(current.copyWith(days: days, refreshing: true));
    } else {
      emit(const FeedbackSummaryLoading());
    }
    try {
      final summary = await _repository.summary(days);
      emit(FeedbackSummaryLoaded(summary, days));
    } on Failure catch (failure) {
      emit(FeedbackSummaryFailure(failure));
    }
  }
}
