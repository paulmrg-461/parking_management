import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/feedback/application/feedback_summary_cubit.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_summary.dart';
import 'package:parking_management/features/feedback/presentation/feedback_summary_page.dart';

import '../../../helpers/fake_feedback_repository.dart';
import '../../../helpers/test_app.dart';

FeedbackSummary _summary({int total = 2}) => FeedbackSummary(
  days: 30,
  startDate: DateTime(2026, 10, 19),
  endDate: DateTime(2026, 11, 17),
  timezone: 'America/Bogota',
  total: total,
  averageX10: 43,
  closedSessions: 300,
  responseRateBp: 400,
  lowCount: 2,
  distribution: const {1: 1, 2: 1, 3: 0, 4: 3, 5: 4},
  recent: [
    FeedbackEntry(
      id: 7,
      sessionId: 55,
      plate: 'MJS368',
      rating: 5,
      comment: 'Muy rápido',
      createdAt: DateTime(2026, 11, 16, 18, 4),
    ),
    FeedbackEntry(
      id: 6,
      sessionId: 54,
      plate: 'ABC123',
      rating: 2,
      comment: '',
      createdAt: DateTime(2026, 11, 15, 9, 30),
    ),
  ],
);

Future<FakeFeedbackRepository> _pump(
  WidgetTester tester, {
  FakeFeedbackRepository? repository,
  Size size = const Size(400, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo =
      repository ?? (FakeFeedbackRepository()..summaryToReturn = _summary());
  final cubit = FeedbackSummaryCubit(repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: const FeedbackSummaryPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('Success: shows the average, the response rate and comments', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('4,3'), findsOne);
    expect(find.text('2'), findsWidgets);
    expect(find.text('4% de las salidas'), findsOne);
    expect(find.text('5 estrellas'), findsOne);
    expect(find.text('Muy rápido'), findsOne);
    expect(find.text('Sin comentario'), findsOne);
    expect(find.text('MJS368'), findsOne);
  });

  testWidgets('Success: a period switch reloads with the new window', (
    tester,
  ) async {
    final repository = await _pump(tester);

    await tester.tap(find.byKey(const Key('feedback-period-7')));
    await tester.pumpAndSettle();

    expect(repository.lastDays, 7);
    expect(find.text('4,3'), findsOne);
  });

  testWidgets('Failure: an empty period shows the call to action', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeFeedbackRepository()
        ..summaryToReturn = _summary(total: 0),
    );

    expect(find.text('Aún no hay calificaciones'), findsOne);
    expect(find.text('Actualizar'), findsOne);
  });

  testWidgets('Failure: a failed load offers a retry that recovers', (
    tester,
  ) async {
    final repository = FakeFeedbackRepository()
      ..summaryError = const ServerFailure('down');
    await _pump(tester, repository: repository);

    expect(
      find.text(
        'El servidor no está disponible. Intenta de nuevo en un momento',
      ),
      findsOne,
    );

    repository
      ..summaryError = null
      ..summaryToReturn = _summary();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('4,3'), findsOne);
  });

  testWidgets('Security: the report is read only (no edit actions)', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Success: the report fits 400 dp with large text', (
    tester,
  ) async {
    await _pump(tester, size: const Size(400, 2000), textScale: 1.6);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Accessibility: chips and buttons meet the tap target guides', (
    tester,
  ) async {
    await _pump(tester);

    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
