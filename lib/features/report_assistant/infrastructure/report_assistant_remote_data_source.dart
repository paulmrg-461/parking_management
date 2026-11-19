import '../../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/assistant_answer.dart';
import '../domain/entities/assistant_progress.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_turn.dart';
import 'sse_event_parser.dart';

typedef FunctionsInvoker = Future<Object?> Function(
  String name,
  Map<String, dynamic> body, {
  Map<String, String>? headers,
});

abstract class ReportAssistantRemoteDataSource {
  Future<AssistantStatus> status();
  Stream<AssistantEvent> ask(
    AssistantQuestion question,
    List<AssistantTurn> history,
  );
}

class SupabaseReportAssistantRemoteDataSource
    implements ReportAssistantRemoteDataSource {
  SupabaseReportAssistantRemoteDataSource(this._invoke);

  final FunctionsInvoker _invoke;

  @override
  Future<AssistantStatus> status() async {
    try {
      final data = await _invoke('report-assistant', {'mode': 'status'});
      if (data is Map) {
        return AssistantStatus.fromJson(Map<String, dynamic>.from(data));
      }
      return const AssistantStatus();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Stream<AssistantEvent> ask(
    AssistantQuestion question,
    List<AssistantTurn> history,
  ) async* {
    final body = {
      'mode': 'ask',
      'question': question.text,
      'locale': question.locale,
      'history': [
        for (final turn in history.where((turn) => turn.answer != null).take(6))
          {'q': turn.question, 'a': turn.answer!.headline},
      ],
    };
    Object? data;
    try {
      data = await _invoke(
        'report-assistant',
        body,
        headers: {'Accept': 'text/event-stream'},
      );
    } catch (error) {
      throw _mapFunctionError(error);
    }
    if (data is Stream<List<int>>) {
      yield* parseAssistantSse(data);
      return;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final answer = map['answer'];
      if (answer is Map) {
        yield AssistantAnswered(
          AssistantAnswer.fromJson(Map<String, dynamic>.from(answer)),
        );
      }
      yield const AssistantDone();
      return;
    }
    throw const ValidationFailure('AiUpstreamError', 'AiUpstreamError');
  }

  Failure _mapFunctionError(Object error) {
    try {
      final dynamic dynamicError = error;
      final status = dynamicError.status as int?;
      final details = dynamicError.details;
      final message = details is Map ? details['message'] : null;
      if (message is String && RegExp(r'^[A-Za-z]+Error$').hasMatch(message)) {
        return ValidationFailure(message, message);
      }
      return status == null
          ? const NetworkFailure('offline')
          : ServerFailure('AI request failed', 'AiUpstreamError');
    } catch (_) {
      return const NetworkFailure('offline');
    }
  }
}
