import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/period_comparison.dart';
import 'package:parking_management/features/reports/presentation/widgets/period_comparison_section.dart';

import '../../../helpers/test_app.dart';

PeriodWindow _window({
  int revenue = 0,
  int days = 30,
  bool fullMonth = true,
  bool covered = true,
  int entries = 0,
}) => PeriodWindow(
  startDate: DateTime(2026, 9),
  endDate: DateTime(2026, 9, days),
  days: days,
  fullMonth: fullMonth,
  covered: covered,
  revenue: revenue,
  entries: entries,
);

PeriodComparison _comparison({
  bool partial = false,
  bool coveredBase = true,
  int current = 12400000,
  int previous = 11800000,
  int lastYear = 0,
}) => PeriodComparison(
  months: 1,
  timezone: 'America/Bogota',
  buckets: [
    PeriodBucket(
      month: DateTime(2026, 10),
      isPartial: partial,
      current: _window(
        revenue: current,
        days: partial ? 10 : 31,
        fullMonth: !partial,
        entries: 3,
      ),
      previousMonth: _window(
        revenue: previous,
        days: partial ? 10 : 31,
        fullMonth: !partial,
        covered: coveredBase,
      ),
      previousYear: _window(revenue: lastYear, covered: false),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required PeriodComparison comparison,
  bool loading = false,
  bool failed = false,
  int months = 6,
  Size size = const Size(800, 1600),
  ValueChanged<int>? onMonthsChanged,
  VoidCallback? onRetry,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: SingleChildScrollView(
          child: PeriodComparisonSection(
            comparison: comparison,
            months: months,
            loading: loading,
            failed: failed,
            onMonthsChanged: onMonthsChanged ?? (_) {},
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: renders the chart, the summary and a row per month', (
    tester,
  ) async {
    await _pump(tester, comparison: _comparison());

    expect(find.text('Comparación por periodo'), findsOneWidget);
    expect(find.byKey(const Key('period-chart')), findsOneWidget);
    expect(find.byKey(const Key('period-bar-2026-10')), findsOneWidget);
    expect(find.byKey(const Key('period-row-2026-10')), findsOneWidget);
    expect(find.text(r'$12.400.000'), findsWidgets);
  });

  testWidgets('Success: growth shows a +5 % chip against the previous month', (
    tester,
  ) async {
    await _pump(tester, comparison: _comparison());

    expect(find.text('+5 % vs mes anterior'), findsWidgets);
    // The year base is never covered in this fixture: no invented chip.
    expect(find.text('Sin base de comparación'), findsWidgets);
  });

  testWidgets('Success: a partial month is labelled and chipped', (
    tester,
  ) async {
    await _pump(tester, comparison: _comparison(partial: true));

    expect(find.byKey(const Key('period-partial-chip')), findsOneWidget);
    expect(find.text('Parcial'), findsWidgets);
    expect(find.text('Mes en curso · 10 de 31 días'), findsOneWidget);
    expect(
      find.text('Se compara con los primeros 10 días de cada mes'),
      findsOneWidget,
    );
  });

  testWidgets('Success: choosing 12 months calls back', (tester) async {
    int? requested;
    await _pump(
      tester,
      comparison: _comparison(),
      onMonthsChanged: (months) => requested = months,
    );

    await tester.tap(find.byKey(const Key('period-months-12')));
    await tester.pumpAndSettle();

    expect(requested, 12);
  });

  testWidgets('Failure: a failed comparison offers a retry', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      comparison: PeriodComparison.empty,
      failed: true,
      onRetry: () => retried++,
    );

    expect(find.text('No se pudo cargar la comparación.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('period-retry')));
    await tester.pumpAndSettle();
    expect(retried, 1);
  });

  testWidgets('Empty: no history explains itself', (tester) async {
    await _pump(tester, comparison: PeriodComparison.empty);

    expect(find.text('Aún no hay historial'), findsOneWidget);
  });

  testWidgets('Success: loading shows the section skeleton', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: PeriodComparisonSection(
            comparison: PeriodComparison.empty,
            months: 6,
            loading: true,
            onMonthsChanged: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('period-chart')), findsNothing);
  });

  testWidgets('A11y: a 400 px phone with large text does not overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      comparison: _comparison(partial: true),
      size: const Size(400, 2400),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('period-chart')), findsOneWidget);
  });
}
