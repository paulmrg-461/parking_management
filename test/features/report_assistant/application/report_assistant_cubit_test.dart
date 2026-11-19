import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/report_assistant/application/report_assistant_cubit.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_progress.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_status.dart';

import '../../../helpers/fake_report_assistant_repository.dart';

void main() {
  AssistantReady ready(ReportAssistantCubit cubit) =>
      cubit.state as AssistantReady;

  test('Success: load emits ready empty when configured', () async {
    final cubit = ReportAssistantCubit(FakeReportAssistantRepository());
    await cubit.load();
    expect(ready(cubit).turns, isEmpty);
    expect(ready(cubit).status.remainingRequests, 100);
    await cubit.close();
  });

  test('Failure: load not configured emits not configured', () async {
    final cubit = ReportAssistantCubit(
      FakeReportAssistantRepository(
        statusResult: const AssistantStatus(configured: false),
      ),
    );
    await cubit.load();
    expect(cubit.state, isA<AssistantNotConfigured>());
    await cubit.close();
  });

  test('Failure: load failure emits failure and retry recovers', () async {
    final repository = FakeReportAssistantRepository()
      ..statusError = const NetworkFailure('offline');
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();
    expect(cubit.state, isA<AssistantFailure>());

    repository.statusError = null;
    await cubit.load();
    expect(cubit.state, isA<AssistantReady>());
    await cubit.close();
  });

  test('Success: ask appends the answered turn and updates the budget', () async {
    final repository = FakeReportAssistantRepository();
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();

    await cubit.ask('¿Cuánto generaron las motos?');

    final turns = ready(cubit).turns;
    expect(turns, hasLength(1));
    expect(turns.single.answer?.headline, contains('{f1}'));
    expect(turns.single.isRunning, isFalse);
    expect(ready(cubit).status.remainingRequests, 99);
    expect(repository.lastQuestion, '¿Cuánto generaron las motos?');
    await cubit.close();
  });

  test('Failure: an ask failure keeps the conversation and marks the turn', () async {
    final repository = FakeReportAssistantRepository()
      ..askError = const ValidationFailure(
        'AiBudgetExceededError',
        'AiBudgetExceededError',
      );
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();

    await cubit.ask('pregunta');

    final turn = ready(cubit).turns.single;
    expect(turn.failure?.code, 'AiBudgetExceededError');
    expect(turn.isRunning, isFalse);
    await cubit.close();
  });

  test('Security: AiUnavailable switches to not configured', () async {
    final cubit = ReportAssistantCubit(
      FakeReportAssistantRepository(events: const [
        AssistantError('AiUnavailableError'),
      ]),
    );
    await cubit.load();
    await cubit.ask('pregunta');
    expect(cubit.state, isA<AssistantNotConfigured>());
    await cubit.close();
  });

  test('Success: history is the last six answered turns', () async {
    final repository = FakeReportAssistantRepository();
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();
    for (var index = 0; index < 7; index++) {
      await cubit.ask('q$index');
    }
    expect(repository.lastHistory.length, 6);
    await cubit.close();
  });

  test('Success: retry reasks the same question and clear empties the chat', () async {
    final repository = FakeReportAssistantRepository(
      events: const [AssistantError('AiTimeoutError')],
    );
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();
    await cubit.ask('pregunta');
    final id = ready(cubit).turns.single.id;
    await cubit.retry(id);
    expect(repository.askCalls, 2);

    repository.events = [
      AssistantAnswered(sampleAnswer()),
      const AssistantDone(remainingRequests: 99),
    ];
    await cubit.retry(id);
    cubit.clear();
    expect(ready(cubit).turns, isEmpty);
    await cubit.close();
  });

  test('Security: ask is ignored when the budget is zero', () async {
    final repository = FakeReportAssistantRepository(
      statusResult: const AssistantStatus(
        configured: true,
        dailyRequests: 100,
        remainingRequests: 0,
      ),
    );
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();
    await cubit.ask('pregunta');
    expect(repository.askCalls, 0);
    expect(ready(cubit).turns, isEmpty);
    await cubit.close();
  });

  test('Success: an empty question is ignored', () async {
    final repository = FakeReportAssistantRepository();
    final cubit = ReportAssistantCubit(repository);
    await cubit.load();
    await cubit.ask('   ');
    expect(repository.askCalls, 0);
    await cubit.close();
  });

  test('Failure: a malformed stream event fails the turn', () async {
    final cubit = ReportAssistantCubit(
      FakeReportAssistantRepository(
        events: const [AssistantMalformed()],
      ),
    );
    await cubit.load();
    await cubit.ask('pregunta');
    final turn = (cubit.state as AssistantReady).turns.single;
    expect(turn.failure?.code, 'AiAnswerInvalidError');
    expect(turn.isRunning, isFalse);
    await cubit.close();
  });

  test('Success: cancel clears the running flag', () async {
    final cubit = ReportAssistantCubit(FakeReportAssistantRepository());
    await cubit.load();
    cubit.cancel();
    expect(cubit.state, isA<AssistantReady>());
    await cubit.close();
  });
}
