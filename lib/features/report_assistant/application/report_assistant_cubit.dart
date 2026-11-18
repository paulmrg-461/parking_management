import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/assistant_progress.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_turn.dart';
import '../domain/repositories/report_assistant_repository.dart';

sealed class ReportAssistantState extends Equatable {
  const ReportAssistantState();

  @override
  List<Object?> get props => const [];
}

final class AssistantLoading extends ReportAssistantState {
  const AssistantLoading();
}

final class AssistantNotConfigured extends ReportAssistantState {
  const AssistantNotConfigured();
}

final class AssistantFailure extends ReportAssistantState {
  const AssistantFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class AssistantReady extends ReportAssistantState {
  const AssistantReady(this.turns, this.status);

  final List<AssistantTurn> turns;
  final AssistantStatus status;

  AssistantReady copyWith({List<AssistantTurn>? turns, AssistantStatus? status}) =>
      AssistantReady(turns ?? this.turns, status ?? this.status);

  @override
  List<Object?> get props => [turns, status];
}

class ReportAssistantCubit extends ResilientCubit<ReportAssistantState> {
  ReportAssistantCubit(this._repository) : super(const AssistantLoading());

  final ReportAssistantRepository _repository;
  StreamSubscription<AssistantEvent>? _subscription;
  int _nextId = 1;
  bool _running = false;

  Future<void> load() async {
    emit(const AssistantLoading());
    try {
      final status = await _repository.status();
      emit(
        status.configured
            ? AssistantReady(const [], status)
            : const AssistantNotConfigured(),
      );
    } on Failure catch (failure) {
      emit(AssistantFailure(failure));
    }
  }

  Future<void> ask(String text) async {
    final current = state;
    if (current is! AssistantReady || _running) {
      return;
    }
    final question = text.trim();
    if (question.isEmpty || current.status.remainingRequests == 0) {
      return;
    }
    final turn = AssistantTurn(id: _nextId++, question: question, isRunning: true);
    final withTurn = current.copyWith(turns: [...current.turns, turn]);
    emit(withTurn);
    await _run(question, turn.id);
  }

  Future<void> retry(int turnId) async {
    final current = state;
    if (current is! AssistantReady) {
      return;
    }
    final turn = current.turns.firstWhere(
      (item) => item.id == turnId,
      orElse: () => AssistantTurn(id: turnId, question: ''),
    );
    if (turn.question.isEmpty) {
      return;
    }
    emit(
      current.copyWith(
        turns: [
          for (final item in current.turns)
            if (item.id == turnId)
              item.copyWith(
                isRunning: true,
                failure: null,
                tools: const [],
              )
            else
              item,
        ],
      ),
    );
    await _run(turn.question, turnId);
  }

  Future<void> _run(String question, int turnId) async {
    final current = state;
    if (current is! AssistantReady) {
      return;
    }
    _running = true;
    final history = current.turns
        .where((turn) => turn.answer != null && turn.id != turnId)
        .toList();
    final locale = question.runes.length > 0 ? 'es' : 'es';
    try {
      await for (final event in _repository.ask(
        AssistantQuestion(text: question, locale: locale),
        history,
      )) {
        final latest = state;
        if (latest is! AssistantReady) {
          return;
        }
        final turns = List<AssistantTurn>.of(latest.turns);
        final index = turns.indexWhere((turn) => turn.id == turnId);
        if (index < 0) {
          return;
        }
        final turn = turns[index];
        switch (event) {
          case AssistantStarted():
            break;
          case AssistantToolEvent(:final progress):
            final tools = [...turn.tools];
            final at = tools.indexWhere((item) => item.callId == progress.callId);
            if (at >= 0) {
              tools[at] = tools[at].copyWith(
                state: progress.state,
                ms: progress.ms,
                code: progress.code,
              );
            } else {
              tools.add(progress);
            }
            turns[index] = turn.copyWith(tools: tools);
          case AssistantAnswered(:final answer):
            turns[index] = turn.copyWith(
              answer: answer,
              isRunning: false,
              failure: null,
            );
          case AssistantError(:final code):
            turns[index] = turn.copyWith(
              isRunning: false,
              failure: ValidationFailure(code, code),
            );
            if (code == 'AiUnavailableError') {
              emit(const AssistantNotConfigured());
              return;
            }
          case AssistantDone(:final remainingRequests, :final remainingTokens):
            final status = latest.status.copyWith(
              remainingRequests: remainingRequests,
              remainingTokens: remainingTokens,
            );
            emit(latest.copyWith(turns: turns, status: status));
            continue;
          case AssistantMalformed():
            turns[index] = turn.copyWith(
              isRunning: false,
              failure: const ValidationFailure(
                'AiAnswerInvalidError',
                'AiAnswerInvalidError',
              ),
            );
        }
        emit(latest.copyWith(turns: turns));
      }
    } on Failure catch (failure) {
      _failTurn(turnId, failure);
    } finally {
      _running = false;
    }
  }

  void _failTurn(int turnId, Failure failure) {
    final current = state;
    if (current is! AssistantReady) {
      return;
    }
    emit(
      current.copyWith(
        turns: [
          for (final turn in current.turns)
            if (turn.id == turnId)
              turn.copyWith(isRunning: false, failure: failure)
            else
              turn,
        ],
      ),
    );
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    _running = false;
    final current = state;
    if (current is AssistantReady) {
      emit(
        current.copyWith(
          turns: [
            for (final turn in current.turns)
              if (turn.isRunning) turn.copyWith(isRunning: false) else turn,
          ],
        ),
      );
    }
  }

  void clear() {
    final current = state;
    if (current is AssistantReady) {
      emit(current.copyWith(turns: const []));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
