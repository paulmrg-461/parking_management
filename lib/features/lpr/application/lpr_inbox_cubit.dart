import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../../check_in/domain/entities/parking_session.dart';
import '../domain/commands/confirm_lpr_entry.dart';
import '../domain/entities/lpr_event.dart';
import '../domain/repositories/lpr_repository.dart';

sealed class LprInboxState {
  const LprInboxState();
}

final class LprInboxLoading extends LprInboxState {
  const LprInboxLoading();
}

final class LprInboxFailure extends LprInboxState {
  const LprInboxFailure(this.failure);
  final Failure failure;
}

final class LprInboxEmpty extends LprInboxState {
  const LprInboxEmpty({this.submission = const SubmissionIdle()});
  final Submission submission;

  LprInboxEmpty withSubmission(Submission value) =>
      LprInboxEmpty(submission: value);
}

final class LprInboxLoaded extends LprInboxState {
  const LprInboxLoaded(this.events, {this.submission = const SubmissionIdle()});
  final List<LprEvent> events;
  final Submission submission;

  LprInboxLoaded withSubmission(Submission value) =>
      LprInboxLoaded(events, submission: value);
  LprInboxLoaded without(int eventId) => LprInboxLoaded(
    [for (final event in events) if (event.id != eventId) event],
    submission: submission,
  );
}

/// Pending reads for the gate. Polls every [pollInterval] while the page is
/// open; the timer is cancelled on [close] so a closed cubit never emits.
class LprInboxCubit extends ResilientCubit<LprInboxState> {
  LprInboxCubit(this._repository) : super(const LprInboxLoading());

  static const pollInterval = Duration(seconds: 10);

  final LprRepository _repository;
  Timer? _timer;

  @visibleForTesting
  bool get isPolling => _timer != null;

  Future<void> load() async {
    emit(const LprInboxLoading());
    await _fetch();
  }

  Future<void> confirm(ConfirmLprEntry command) async {
    final current = state;
    final busy = switch (current) {
      LprInboxLoaded(:final submission) => submission.isInProgress,
      LprInboxEmpty(:final submission) => submission.isInProgress,
      _ => true,
    };
    if (busy) return;
    emit(_withSubmission(current, const SubmissionInProgress()));
    try {
      final session = await _repository.confirmEntry(command);
      final refreshed = await _repository.listEvents();
      emit(
        refreshed.isEmpty
            ? LprInboxEmpty(
                submission: SubmissionSucceeded<ParkingSession>(session),
              )
            : LprInboxLoaded(
                refreshed,
                submission: SubmissionSucceeded<ParkingSession>(session),
              ),
      );
    } on Failure catch (failure) {
      emit(_withSubmission(current, SubmissionFailed.of(failure)));
    }
  }

  Future<void> dismiss(int eventId, {String? note}) async {
    final current = state;
    if (current is! LprInboxLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.withSubmission(const SubmissionInProgress()));
    try {
      await _repository.dismiss(eventId, note: note);
      final refreshed = await _repository.listEvents();
      emit(
        refreshed.isEmpty
            ? const LprInboxEmpty(
                submission: SubmissionSucceeded<void>(null),
              )
            : LprInboxLoaded(
                refreshed,
                submission: const SubmissionSucceeded<void>(null),
              ),
      );
    } on Failure catch (failure) {
      emit(current.withSubmission(SubmissionFailed.of(failure)));
    }
  }

  void startPolling() {
    _timer ??= Timer.periodic(pollInterval, (_) => _fetch(silent: true));
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) emit(const LprInboxLoading());
    try {
      final events = await _repository.listEvents();
      emit(events.isEmpty ? const LprInboxEmpty() : LprInboxLoaded(events));
    } on Failure catch (failure) {
      emit(LprInboxFailure(failure));
    }
  }

  LprInboxState _withSubmission(LprInboxState current, Submission value) =>
      switch (current) {
        LprInboxLoaded() => current.withSubmission(value),
        LprInboxEmpty() => current.withSubmission(value),
        _ => current,
      };
}
