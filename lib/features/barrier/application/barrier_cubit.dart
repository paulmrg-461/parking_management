import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/commands/barrier_config_update.dart';
import '../domain/commands/open_barrier_request.dart';
import '../domain/entities/barrier.dart';
import '../domain/entities/barrier_command.dart';
import '../domain/repositories/barrier_repository.dart';

sealed class BarrierState {
  const BarrierState();
}

final class BarrierLoading extends BarrierState {
  const BarrierLoading();
}

final class BarrierFailure extends BarrierState {
  const BarrierFailure(this.failure);
  final Failure failure;
}

final class BarrierEmpty extends BarrierState {
  const BarrierEmpty({this.submission = const SubmissionIdle()});
  final Submission submission;

  BarrierEmpty withSubmission(Submission value) =>
      BarrierEmpty(submission: value);
}

final class BarrierLoaded extends BarrierState {
  const BarrierLoaded(
    this.barriers, {
    this.submission = const SubmissionIdle(),
    this.tracking,
  });

  final List<Barrier> barriers;
  final Submission submission;
  final BarrierCommand? tracking;

  BarrierLoaded copyWith({
    List<Barrier>? barriers,
    Submission? submission,
    BarrierCommand? tracking,
  }) => BarrierLoaded(
    barriers ?? this.barriers,
    submission: submission ?? this.submission,
    tracking: tracking ?? this.tracking,
  );
}

/// The barriers of the active lot: status, manual opening (with a reason and
/// a 1 s tracking poll for up to 40 s) and the admin configuration.
class BarrierCubit extends ResilientCubit<BarrierState> {
  BarrierCubit(this._repository) : super(const BarrierLoading());

  static const pollInterval = Duration(seconds: 1);
  static const maxPolls = 40;

  final BarrierRepository _repository;
  Timer? _timer;
  int _polls = 0;

  @visibleForTesting
  bool get isTracking => _timer != null;

  Future<void> load() async {
    emit(const BarrierLoading());
    await _fetch();
  }

  Future<void> openManually(OpenBarrierRequest request) async {
    final current = state;
    if (current is! BarrierLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final command = await _repository.openManually(request);
      emit(current.copyWith(
        submission: const SubmissionSucceeded<void>(null),
        tracking: command,
      ));
      _startTracking(command.id);
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> saveConfig(BarrierConfigUpdate update) async {
    final current = state;
    if (current is! BarrierLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final barriers = await _repository.list();
      emit(BarrierLoaded(
        barriers,
        submission: const SubmissionSucceeded<void>(null),
        tracking: current.tracking,
      ));
      await _repository.saveConfig(update);
      await _fetch(silent: true);
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<List<BarrierCommand>> history(int deviceId) =>
      _repository.history(deviceId: deviceId);

  void _startTracking(String commandId) {
    _timer?.cancel();
    _polls = 0;
    _timer = Timer.periodic(pollInterval, (_) => _poll(commandId));
  }

  Future<void> _poll(String commandId) async {
    final current = state;
    if (current is! BarrierLoaded) {
      _stopTracking();
      return;
    }
    _polls += 1;
    if (_polls > maxPolls) {
      _stopTracking();
      return;
    }
    try {
      final command = await _repository.command(commandId);
      emit(current.copyWith(tracking: command));
      if (command.status.isTerminal) {
        _stopTracking();
        await _fetch(silent: true);
      }
    } on Failure catch (failure) {
      _stopTracking();
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  void _stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopTracking();
    return super.close();
  }

  Future<void> _fetch({bool silent = false}) async {
    final current = state;
    final submission = silent && current is BarrierLoaded
        ? current.submission
        : const SubmissionIdle();
    final tracking = silent && current is BarrierLoaded
        ? current.tracking
        : null;
    if (!silent) emit(const BarrierLoading());
    try {
      final barriers = await _repository.list();
      emit(barriers.isEmpty
          ? BarrierEmpty(submission: submission)
          : BarrierLoaded(
              barriers,
              submission: submission,
              tracking: tracking,
            ));
    } on Failure catch (failure) {
      emit(BarrierFailure(failure));
    }
  }
}
