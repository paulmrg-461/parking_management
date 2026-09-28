import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// Status of a user action (create/update/delete/check-out...) kept
/// ORTHOGONAL to the loaded data: a failing action never wipes the list.
sealed class Submission extends Equatable {
  const Submission();

  bool get isInProgress => this is SubmissionInProgress;

  @override
  List<Object?> get props => const [];
}

final class SubmissionIdle extends Submission {
  const SubmissionIdle();
}

final class SubmissionInProgress extends Submission {
  const SubmissionInProgress();
}

final class SubmissionFailed extends Submission {
  const SubmissionFailed(this.message, {this.failure});

  /// Carries the [Failure] so presentation can localize it by `code`.
  SubmissionFailed.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  /// Only the text and code: two failures reporting the same problem are
  /// the same submission outcome.
  @override
  List<Object?> get props => [message, failure?.code];
}

/// Completed action carrying its [result] (receipt, created session...).
final class SubmissionSucceeded<T> extends Submission {
  const SubmissionSucceeded(this.result);

  final T result;

  @override
  List<Object?> get props => [result];
}

/// `true` exactly when [current] became a failure (for `listenWhen`).
bool submissionJustFailed(Submission? previous, Submission? current) =>
    current is SubmissionFailed && previous != current;

/// `true` exactly when [current] became a success (for `listenWhen`).
bool submissionJustSucceeded(Submission? previous, Submission? current) =>
    current is SubmissionSucceeded && previous != current;
