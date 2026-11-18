import 'dart:async';

import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_answer.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_progress.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_status.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_turn.dart';
import 'package:parking_management/features/report_assistant/domain/repositories/report_assistant_repository.dart';

AssistantAnswer sampleAnswer({int value = 4820000}) => AssistantAnswer(
  status: AnswerStatus.answered,
  headline: 'Las motos generaron {f1}.',
  explanation: 'Según el reporte de ingresos.',
  figures: [
    AssistantFigure(
      id: 'f1',
      label: 'Ingresos motos',
      unit: FigureUnit.money,
      op: 'value',
      value: value,
      sources: const [
        FigureSource(
          callId: 'call1',
          rpc: 'report_revenue',
          args: {'p_start_date': '2026-10-01'},
          path: 'by_category[category_name=Moto].amount',
          raw: 4820000,
        ),
      ],
    ),
  ],
);

class FakeReportAssistantRepository implements ReportAssistantRepository {
  FakeReportAssistantRepository({
    this.statusResult = const AssistantStatus(
      configured: true,
      dailyRequests: 100,
      remainingRequests: 100,
    ),
    List<AssistantEvent>? events,
  }) : events = events ?? [
         AssistantStarted(1),
         AssistantAnswered(sampleAnswer()),
         const AssistantDone(remainingRequests: 99, remainingTokens: 900),
       ];

  AssistantStatus statusResult;
  List<AssistantEvent> events;
  Failure? statusError;
  Failure? askError;
  int statusCalls = 0;
  int askCalls = 0;
  List<AssistantTurn> lastHistory = const [];
  String? lastQuestion;

  @override
  Future<AssistantStatus> status() async {
    statusCalls++;
    final error = statusError;
    if (error != null) throw error;
    return statusResult;
  }

  @override
  Stream<AssistantEvent> ask(
    AssistantQuestion question,
    List<AssistantTurn> history,
  ) async* {
    askCalls++;
    lastQuestion = question.text;
    lastHistory = history;
    final error = askError;
    if (error != null) throw error;
    for (final event in events) {
      yield event;
    }
  }
}
