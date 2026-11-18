import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_answer.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_progress.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_status.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_turn.dart';
import 'package:parking_management/features/report_assistant/infrastructure/report_assistant_remote_data_source.dart';
import 'package:parking_management/features/report_assistant/infrastructure/report_assistant_repository_impl.dart';

import '../../../helpers/fake_report_assistant_repository.dart';

Stream<List<int>> _sse(List<String> blocks) async* {
  for (final block in blocks) {
    yield utf8.encode(block);
  }
}

class _FunctionException implements Exception {
  _FunctionException(this.status, this.details);
  final int status;
  final Map<String, dynamic> details;
}

void main() {
  test('status maps configured and budget', () async {
    final remote = SupabaseReportAssistantRemoteDataSource((name, body, {headers}) async {
      expect(name, 'report-assistant');
      expect(body['mode'], 'status');
      return {
        'configured': true,
        'budget': {'daily_requests': 100, 'remaining_requests': 98},
      };
    });
    final status = await remote.status();
    expect(status.configured, isTrue);
    expect(status.remainingRequests, 98);
  });

  test('ask sends the question, locale and capped history', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseReportAssistantRemoteDataSource((name, body, {headers}) async {
      sent = body;
      expect(headers?['Accept'], 'text/event-stream');
      return _sse([
        'event: answer\ndata: {"status":"answered","headline":"x","figures":[]}\n\n',
        'event: done\ndata: {"remaining":{"requests":97}}\n\n',
      ]);
    });
    final history = [
      for (var index = 0; index < 7; index++)
        AssistantTurn(
          id: index,
          question: 'q$index',
          answer: sampleAnswer(),
        ),
    ];
    final events = await remote
        .ask(const AssistantQuestion(text: '¿Cuánto?'), history)
        .toList();

    expect((sent!['history'] as List).length, 6);
    expect(sent!['locale'], 'es');
    expect(events.whereType<AssistantAnswered>(), hasLength(1));
    expect(events.whereType<AssistantDone>(), hasLength(1));
  });

  test('ask supports the JSON fallback', () async {
    final remote = SupabaseReportAssistantRemoteDataSource((name, body, {headers}) async => {
      'answer': {
        'status': 'answered',
        'headline': 'x',
        'figures': <Object>[],
      },
    });
    final events = await remote
        .ask(const AssistantQuestion(text: 'q'), const [])
        .toList();
    expect(events.first, isA<AssistantAnswered>());
    expect(events.last, isA<AssistantDone>());
  });

  test('a typed FunctionException becomes a ValidationFailure', () async {
    final remote = SupabaseReportAssistantRemoteDataSource((name, body, {headers}) async {
      throw _FunctionException(429, {'message': 'AiBudgetExceededError'});
    });
    expect(
      () => remote.ask(const AssistantQuestion(text: 'q'), const []).toList(),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'AiBudgetExceededError',
        ),
      ),
    );
  });

  test('a socket error becomes a NetworkFailure', () async {
    final remote = SupabaseReportAssistantRemoteDataSource((name, body, {headers}) async {
      throw Exception('offline');
    });
    expect(
      () => remote.status(),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('the repository delegates', () async {
    final fake = FakeReportAssistantRepository();
    final impl = ReportAssistantRepositoryImpl(_Remote(fake));
    expect((await impl.status()).configured, isTrue);
    await impl.ask(const AssistantQuestion(text: 'q'), const []).toList();
    expect(fake.askCalls, 1);
  });
}

class _Remote implements ReportAssistantRemoteDataSource {
  _Remote(this.fake);
  final FakeReportAssistantRepository fake;

  @override
  Future<AssistantStatus> status() => fake.status();

  @override
  Stream<AssistantEvent> ask(AssistantQuestion question, List<AssistantTurn> history) =>
      fake.ask(question, history);
}
