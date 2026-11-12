import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/anomalies/application/anomalies_cubit.dart';
import 'package:parking_management/features/anomalies/domain/entities/cash_anomaly.dart';
import 'package:parking_management/features/anomalies/presentation/anomalies_page.dart';

import '../../../helpers/fake_anomaly_repository.dart';
import '../../../helpers/test_app.dart';

Future<AnomaliesCubit> _pump(
  WidgetTester tester,
  FakeAnomalyRepository repository,
) async {
  final cubit = AnomaliesCubit(repository);
  addTearDown(cubit.close);
  await tester.runAsync(cubit.load);
  await tester.pumpWidget(
    testApp(BlocProvider.value(value: cubit, child: const AnomaliesPage())),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Success: lists anomalies with severity and operator', (
    tester,
  ) async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);

    await _pump(tester, repository);

    expect(find.text('Alta'), findsOneWidget);
    expect(find.text('Salida sin cobro'), findsOneWidget);
    expect(find.textContaining('ABC123'), findsWidgets);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('1 abierta'), findsOneWidget);
  });

  testWidgets('Success: acknowledge sends the status without a note', (
    tester,
  ) async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('anomaly-ack-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anomaly-resolve-save')));
    await tester.pumpAndSettle();

    expect(repository.resolved.single.$2, AnomalyStatus.acknowledged);
    expect(repository.resolved.single.$3, isNull);
  });

  testWidgets('Failure: dismiss requires a note', (tester) async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('anomaly-dismiss-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anomaly-resolve-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe una nota de al menos 3 caracteres'),
      findsWidgets,
    );
    expect(repository.resolved, isEmpty);
  });

  testWidgets('Success: dismiss sends the note', (tester) async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('anomaly-dismiss-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.enterText(
      find.byKey(const Key('anomaly-note')),
      'revisado con el operador',
    );
    await tester.tap(find.byKey(const Key('anomaly-resolve-save')));
    await tester.pumpAndSettle();

    expect(repository.resolved.single.$3, 'revisado con el operador');
  });

  testWidgets('Failure: empty state offers clearing the filters', (
    tester,
  ) async {
    final repository = FakeAnomalyRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('anomalies-status-dismissed')));
    await tester.pumpAndSettle();

    expect(find.text('Todo en orden'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsWidgets);
  });

  testWidgets('Failure: load error shows retry', (tester) async {
    final repository = FakeAnomalyRepository()
      ..listError = const NetworkFailure('offline');

    await _pump(tester, repository);

    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Security: the page never shows a raw threshold table', (
    tester,
  ) async {
    final repository = FakeAnomalyRepository()
      ..listToReturn = AnomalyList(items: [anomaly()], openCount: 1);
    await _pump(tester, repository);

    expect(find.textContaining('window_days'), findsNothing);
  });
}
