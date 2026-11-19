import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/report_assistant/application/report_assistant_cubit.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_answer.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_progress.dart';
import 'package:parking_management/features/report_assistant/domain/entities/assistant_status.dart';
import 'package:parking_management/features/report_assistant/presentation/answer_export.dart';
import 'package:parking_management/features/report_assistant/presentation/report_assistant_page.dart';

import '../../../helpers/fake_report_assistant_repository.dart';
import '../../../helpers/test_app.dart';

Future<ReportAssistantCubit> _pump(
  WidgetTester tester,
  FakeReportAssistantRepository repository, {
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = ReportAssistantCubit(repository);
  addTearDown(cubit.close);
  await cubit.load();
  await tester.pumpWidget(
    testApp(
      BlocProvider<ReportAssistantCubit>.value(
        value: cubit,
        child: const ReportAssistantPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('shows skeleton while loading', (tester) async {
    final cubit = ReportAssistantCubit(FakeReportAssistantRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider<ReportAssistantCubit>.value(
          value: cubit,
          child: const ReportAssistantPage(),
        ),
      ),
    );
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('empty state shows suggestions and tapping one asks it', (
    tester,
  ) async {
    final repository = FakeReportAssistantRepository();
    await _pump(tester, repository);

    expect(find.text('Prueba con'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    expect(repository.askCalls, 1);
    expect(find.byKey(const Key('assistant_answer_card')), findsOneWidget);
    expect(find.textContaining(r'$4.820.000'), findsWidgets);
  });

  testWidgets('shows the not configured state without retry', (tester) async {
    await _pump(
      tester,
      FakeReportAssistantRepository(
        statusResult: const AssistantStatus(configured: false),
      ),
    );

    expect(find.text('El asistente no está activado'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('shows an error state with retry on status failure', (
    tester,
  ) async {
    final repository = FakeReportAssistantRepository()
      ..statusError = const NetworkFailure('offline');
    await _pump(tester, repository);

    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('composer sends the typed question', (tester) async {
    final repository = FakeReportAssistantRepository();
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('assistant_composer')),
      '¿Cuánto entró hoy?',
    );
    await tester.tap(find.byKey(const Key('assistant_send')));
    await tester.pumpAndSettle();

    expect(repository.lastQuestion, '¿Cuánto entró hoy?');
  });

  testWidgets('copy answer puts the text on the clipboard', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final repository = FakeReportAssistantRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant_copy_answer')));
    await tester.pump();

    expect(
      calls.any((call) => call.method == 'Clipboard.setData'),
      isTrue,
    );
  });

  test('csv export keeps raw integers and escapes labels', () {
    final answer = sampleAnswer();
    final csv = answerFiguresCsv(answer);
    expect(csv.split('\n').first, 'label,unit,value,rpc,path');
    expect(csv, contains('4820000'));
    expect(csv.contains(r'$'), isFalse);
  });

  testWidgets('meets tap target guidelines', (tester) async {
    await _pump(tester, FakeReportAssistantRepository());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('a failed turn shows retry and reasks', (tester) async {
    final repository = FakeReportAssistantRepository(
      events: const [AssistantError('AiTimeoutError')],
    );
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    expect(find.textContaining('tardó demasiado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant_retry_1')));
    await tester.pumpAndSettle();
    expect(repository.askCalls, 2);
  });

  testWidgets('tapping a figure opens its source sheet', (tester) async {
    final repository = FakeReportAssistantRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assistant_figure_f1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('report_revenue'), findsOneWidget);
    expect(find.textContaining('by_category'), findsOneWidget);
  });

  testWidgets('a clarification answer shows its status chip', (tester) async {
    final answer = AssistantAnswer(
      status: AnswerStatus.needsClarification,
      headline: sampleAnswer().headline,
      explanation: sampleAnswer().explanation,
      figures: sampleAnswer().figures,
    );
    final repository = FakeReportAssistantRepository(
      events: [
        AssistantAnswered(answer),
        const AssistantDone(remainingRequests: 99),
      ],
    );
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('assistant_suggestion_0')));
    await tester.pumpAndSettle();

    expect(find.text('Necesito un dato más'), findsOneWidget);
  });
}
