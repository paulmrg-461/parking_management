import 'package:equatable/equatable.dart';

import 'assistant_answer.dart';

enum ToolState { running, done, error }

class ToolProgress extends Equatable {
  const ToolProgress({
    required this.callId,
    this.tool = '',
    this.rpc = '',
    this.args = const {},
    this.state = ToolState.running,
    this.ms,
    this.code,
  });

  final String callId;
  final String tool;
  final String rpc;
  final Map<String, String> args;
  final ToolState state;
  final int? ms;
  final String? code;

  ToolProgress copyWith({ToolState? state, int? ms, String? code}) =>
      ToolProgress(
        callId: callId,
        tool: tool,
        rpc: rpc,
        args: args,
        state: state ?? this.state,
        ms: ms ?? this.ms,
        code: code ?? this.code,
      );

  @override
  List<Object?> get props => [callId, tool, rpc, args, state, ms, code];
}

sealed class AssistantEvent extends Equatable {
  const AssistantEvent();

  @override
  List<Object?> get props => const [];
}

final class AssistantStarted extends AssistantEvent {
  const AssistantStarted(this.requestId);
  final int requestId;

  @override
  List<Object?> get props => [requestId];
}

final class AssistantToolEvent extends AssistantEvent {
  const AssistantToolEvent(this.progress);
  final ToolProgress progress;

  @override
  List<Object?> get props => [progress];
}

final class AssistantAnswered extends AssistantEvent {
  const AssistantAnswered(this.answer);
  final AssistantAnswer answer;

  @override
  List<Object?> get props => [answer];
}

final class AssistantError extends AssistantEvent {
  const AssistantError(this.code);
  final String code;

  @override
  List<Object?> get props => [code];
}

final class AssistantDone extends AssistantEvent {
  const AssistantDone({
    this.iterations = 0,
    this.toolCalls = 0,
    this.remainingRequests,
    this.remainingTokens,
  });

  final int iterations;
  final int toolCalls;
  final int? remainingRequests;
  final int? remainingTokens;

  @override
  List<Object?> get props => [
    iterations,
    toolCalls,
    remainingRequests,
    remainingTokens,
  ];
}

final class AssistantMalformed extends AssistantEvent {
  const AssistantMalformed();
}
