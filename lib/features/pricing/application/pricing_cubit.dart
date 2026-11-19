import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/pricing_rule.dart';
import '../domain/entities/pricing_settings.dart';
import '../domain/repositories/pricing_repository.dart';

sealed class PricingState extends Equatable {
  const PricingState();

  @override
  List<Object?> get props => const [];
}

final class PricingInitial extends PricingState {
  const PricingInitial();
}

final class PricingLoading extends PricingState {
  const PricingLoading();
}

final class PricingLoaded extends PricingState {
  const PricingLoaded(
    this.rules,
    this.settings, {
    this.submission = const SubmissionIdle(),
  });

  final List<PricingRule> rules;
  final PricingSettings settings;
  final Submission submission;

  PricingLoaded copyWith({
    List<PricingRule>? rules,
    PricingSettings? settings,
    Submission? submission,
  }) => PricingLoaded(
    rules ?? this.rules,
    settings ?? this.settings,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [rules, settings, submission];
}

final class PricingFailure extends PricingState {
  const PricingFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Rules + settings of the active lot.
class PricingCubit extends ResilientCubit<PricingState> {
  PricingCubit(this._repository) : super(const PricingInitial());

  final PricingRepository _repository;

  Future<void> load() async {
    emit(const PricingLoading());
    try {
      final results = await Future.wait<Object>([
        _repository.listRules(),
        _repository.loadSettings(),
      ]);
      emit(
        PricingLoaded(
          results[0] as List<PricingRule>,
          results[1] as PricingSettings,
        ),
      );
    } on Failure catch (failure) {
      emit(PricingFailure(failure));
    }
  }

  Future<void> saveRule(PricingRuleDraft draft) async {
    final current = state;
    if (current is! PricingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final rule = await _repository.saveRule(draft);
      emit(
        current.copyWith(
          submission: SubmissionSucceeded<PricingRule>(rule),
        ),
      );
      await _refresh();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> toggleRule(PricingRule rule) => saveRule(
    PricingRuleDraft.fromRule(rule).copyWithActive(!rule.active),
  );

  Future<void> deleteRule(int id) async {
    final current = state;
    if (current is! PricingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.deleteRule(id);
      emit(
        current.copyWith(
          rules: [
            for (final rule in current.rules)
              if (rule.id != id) rule,
          ],
          submission: const SubmissionSucceeded<Object?>(null),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> saveSettings(PricingSettings settings) async {
    final current = state;
    if (current is! PricingLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final saved = await _repository.saveSettings(settings);
      emit(
        current.copyWith(
          settings: saved,
          submission: SubmissionSucceeded<PricingSettings>(saved),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> _refresh() async {
    try {
      final rules = await _repository.listRules();
      final latest = state;
      if (latest is PricingLoaded) {
        emit(latest.copyWith(rules: rules));
      }
    } on Failure {
      // Keep the list already on screen.
    }
  }
}

extension on PricingRuleDraft {
  PricingRuleDraft copyWithActive(bool active) => PricingRuleDraft(
    id: id,
    name: name,
    priority: priority,
    group: group,
    minOccupancyPct: minOccupancyPct,
    maxOccupancyPct: maxOccupancyPct,
    weekdays: weekdays,
    fromMinute: fromMinute,
    toMinute: toMinute,
    multiplierBps: multiplierBps,
    surchargeAmount: surchargeAmount,
    active: active,
  );
}
