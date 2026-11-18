import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import 'assistant_answer.dart';
import 'assistant_progress.dart';

class AssistantTurn extends Equatable {
  const AssistantTurn({
    required this.id,
    required this.question,
    this.answer,
    this.failure,
    this.tools = const [],
    this.isRunning = false,
  });

  final int id;
  final String question;
  final AssistantAnswer? answer;
  final Failure? failure;
  final List<ToolProgress> tools;
  final bool isRunning;

  AssistantTurn copyWith({
    AssistantAnswer? answer,
    Failure? failure,
    List<ToolProgress>? tools,
    bool? isRunning,
  }) => AssistantTurn(
    id: id,
    question: question,
    answer: answer ?? this.answer,
    failure: failure ?? this.failure,
    tools: tools ?? this.tools,
    isRunning: isRunning ?? this.isRunning,
  );

  @override
  List<Object?> get props => [id, question, answer, failure, tools, isRunning];
}
