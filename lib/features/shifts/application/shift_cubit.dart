import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/shift_summary.dart';
import '../domain/repositories/shift_repository.dart';

enum ShiftStatus { initial, loading, loaded, failure }

class ShiftState extends Equatable {
  const ShiftState({
    this.status = ShiftStatus.initial,
    this.current,
    this.history = const [],
    this.lastClosed,
    this.submission = const SubmissionIdle(),
    this.error,
    this.historyFrom,
    this.historyTo,
  });

  final ShiftStatus status;
  final ShiftSummary? current;
  final List<ShiftSummary> history;
  final ShiftSummary? lastClosed;
  final Submission submission;
  final Failure? error;

  /// Active admin-history filter (`null` = everything).
  final DateTime? historyFrom;
  final DateTime? historyTo;

  ShiftState copyWith({
    ShiftStatus? status,
    ShiftSummary? current,
    bool clearCurrent = false,
    List<ShiftSummary>? history,
    ShiftSummary? lastClosed,
    Submission? submission,
    Failure? error,
    DateTime? historyFrom,
    DateTime? historyTo,
    bool clearHistoryRange = false,
  }) => ShiftState(
    status: status ?? this.status,
    current: clearCurrent ? null : (current ?? this.current),
    history: history ?? this.history,
    lastClosed: lastClosed ?? this.lastClosed,
    submission: submission ?? this.submission,
    error: error,
    historyFrom: clearHistoryRange ? null : (historyFrom ?? this.historyFrom),
    historyTo: clearHistoryRange ? null : (historyTo ?? this.historyTo),
  );

  @override
  List<Object?> get props =>
      [
        status,
        current,
        history,
        lastClosed,
        submission,
        error,
        historyFrom,
        historyTo,
      ];
}

class ShiftCubit extends ResilientCubit<ShiftState> {
  ShiftCubit(this._repository) : super(const ShiftState());

  final ShiftRepository _repository;

  Future<void> load({
    bool admin = false,
    DateTime? historyFrom,
    DateTime? historyTo,
    bool clearHistoryRange = false,
  }) async {
    emit(state.copyWith(status: ShiftStatus.loading, error: null));
    try {
      final current = await _repository.current();
      final history = admin
          ? await _repository.history(
              from: clearHistoryRange ? null : (historyFrom ?? state.historyFrom),
              to: clearHistoryRange ? null : (historyTo ?? state.historyTo),
            )
          : const <ShiftSummary>[];
      emit(
        state.copyWith(
          status: ShiftStatus.loaded,
          current: current,
          clearCurrent: current == null,
          history: history,
          historyFrom: historyFrom,
          historyTo: historyTo,
          clearHistoryRange: clearHistoryRange,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(status: ShiftStatus.failure, error: failure),
      );
    }
  }

  Future<void> open(int openingFloat) => _submit(
    () => _repository.open(openingFloat),
  );

  Future<void> closeShift({required int countedCash, String? notes}) async {
    await _submit(
      () => _repository.close(countedCash: countedCash, notes: notes),
      onSuccess: (shift) => emit(
        state.copyWith(
          current: null,
          clearCurrent: true,
          lastClosed: shift,
        ),
      ),
    );
  }

  Future<void> adjust({
    required int shiftId,
    required int countedCash,
    required String reason,
  }) async {
    await _submit(
      () => _repository.adjust(
        shiftId: shiftId,
        countedCash: countedCash,
        reason: reason,
      ),
    );
    await load(admin: true);
  }

  Future<void> addMovement({
    required String type,
    required int amount,
    required String reason,
  }) => _submit(
    () => _repository.addMovement(type: type, amount: amount, reason: reason),
  );

  Future<void> _submit(
    Future<ShiftSummary> Function() action, {
    void Function(ShiftSummary)? onSuccess,
  }) async {
    emit(state.copyWith(submission: const SubmissionInProgress(), error: null));
    try {
      final shift = await action();
      emit(
        state.copyWith(
          submission: const SubmissionIdle(),
          current: shift.isOpen ? shift : null,
          clearCurrent: !shift.isOpen,
        ),
      );
      onSuccess?.call(shift);
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          submission: SubmissionFailed.of(failure),
          error: failure,
        ),
      );
    }
  }
}
