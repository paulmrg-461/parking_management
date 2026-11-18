import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/damage_comparison.dart';
import '../domain/repositories/damage_comparison_repository.dart';

sealed class DamageState extends Equatable {
  const DamageState();
  @override
  List<Object?> get props => const [];
}

final class DamageLoading extends DamageState {
  const DamageLoading();
}

final class DamageNotConfigured extends DamageState {
  const DamageNotConfigured();
}

final class DamageFailure extends DamageState {
  const DamageFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

final class DamageLoaded extends DamageState {
  const DamageLoaded({
    required this.view,
    required this.ai,
    this.running = false,
    this.failure,
  });

  final DamageView view;
  final DamageAiStatus ai;
  final bool running;
  final Failure? failure;

  DamageLoaded copyWith({
    DamageView? view,
    DamageAiStatus? ai,
    bool? running,
    Failure? failure,
    bool clearFailure = false,
  }) => DamageLoaded(
    view: view ?? this.view,
    ai: ai ?? this.ai,
    running: running ?? this.running,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [view, ai, running, failure];
}

class DamageComparisonCubit extends ResilientCubit<DamageState> {
  DamageComparisonCubit(this._repository, {required this.sessionId})
    : super(const DamageLoading());

  final DamageComparisonRepository _repository;
  final int sessionId;

  Future<void> load() async {
    emit(const DamageLoading());
    try {
      final ai = await _repository.status();
      final view = await _repository.load(sessionId);
      emit(
        ai.configured
            ? DamageLoaded(view: view, ai: ai)
            : const DamageNotConfigured(),
      );
    } on Failure catch (failure) {
      emit(DamageFailure(failure));
    }
  }

  Future<void> run() async {
    final current = state;
    if (current is! DamageLoaded || current.running ||
        !current.ai.configured) {
      return;
    }
    emit(current.copyWith(running: true, clearFailure: true));
    try {
      final view = await _repository.run(sessionId: sessionId);
      emit(current.copyWith(view: view, running: false, clearFailure: true));
    } on Failure catch (failure) {
      emit(current.copyWith(running: false, failure: failure));
    }
  }

  Future<void> review(
    int findingId,
    FindingReview status,
    String note,
  ) async {
    final current = state;
    if (current is! DamageLoaded) {
      return;
    }
    if (status != FindingReview.open &&
        (note.trim().length < 3 || note.trim().length > 400)) {
      emit(
        current.copyWith(
          failure: const ValidationFailure('InvalidDataError', 'InvalidDataError'),
        ),
      );
      return;
    }
    try {
      final updated = await _repository.review(
        findingId: findingId,
        status: status,
        note: note.trim(),
      );
      final findings = <DamageFinding>[
        for (final finding in current.view.comparison?.findings ?? const [])
          if (finding.id == findingId)
            finding.copyWith(
              reviewStatus: updated.reviewStatus,
              reviewNote: updated.reviewNote,
            )
          else
            finding,
      ];
      final comparison = current.view.comparison;
      emit(
        current.copyWith(
          view: DamageView(
            sessionId: current.view.sessionId,
            runs: current.view.runs,
            stale: current.view.stale,
            comparison: comparison == null
                ? null
                : DamageComparison(
                    id: comparison.id,
                    runNumber: comparison.runNumber,
                    status: comparison.status,
                    overall: comparison.overall,
                    summary: comparison.summary,
                    quality: comparison.quality,
                    model: comparison.model,
                    entryPhotoCount: comparison.entryPhotoCount,
                    exitPhotoCount: comparison.exitPhotoCount,
                    errorCode: comparison.errorCode,
                    createdAt: comparison.createdAt,
                    completedAt: comparison.completedAt,
                    findings: findings,
                  ),
          ),
          clearFailure: true,
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(failure: failure));
    }
  }
}
