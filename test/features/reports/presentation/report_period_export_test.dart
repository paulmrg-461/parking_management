import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/period_comparison.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/presentation/report_csv.dart';
import 'package:parking_management/features/reports/presentation/report_pdf.dart';

import 'package:parking_management/core/l10n/l10n.dart';

PeriodComparison _comparison({bool partial = false}) => PeriodComparison(
  months: 1,
  timezone: 'America/Bogota',
  asOf: DateTime(2026, 10, 31),
  buckets: [
    PeriodBucket(
      month: DateTime(2026, 10),
      isPartial: partial,
      current: PeriodWindow(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        days: partial ? 10 : 31,
        fullMonth: !partial,
        covered: true,
        revenue: 12400000,
        entries: 30,
        exits: 28,
        avgTicket: 442857,
        avgStayMinutes: 90,
        passRevenue: 300000,
        reservations: 4,
        reservationsUsed: 3,
      ),
      previousMonth: PeriodWindow(
        startDate: DateTime(2026, 9),
        endDate: DateTime(2026, 9, 30),
        days: 30,
        fullMonth: true,
        covered: true,
        revenue: 11800000,
      ),
      previousYear: PeriodWindow(
        startDate: DateTime(2025, 10),
        endDate: DateTime(2025, 10, 31),
        days: 31,
        fullMonth: true,
      ),
    ),
  ],
);

final _revenue = RevenueReport(
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 10, 31),
  total: 12400000,
  byDay: const [],
  byCategory: const [],
);

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(defaultLocale);
  });

  test('Success: period CSV rows are raw integers per window', () {
    final csv = reportCsv(revenue: _revenue, comparison: _comparison());
    final lines = csv.split('\n');

    expect(lines, contains('period,as_of,2026-10-31'));
    expect(lines, contains('period_revenue,2026-10,12400000'));
    expect(lines, contains('period_revenue_prev_month,2026-10,11800000'));
    expect(lines, contains('period_revenue_prev_year,2026-10,0'));
    expect(lines, contains('period_avg_stay_minutes,2026-10,90'));
    expect(lines, contains('period_reservations,2026-10,4'));
  });

  test('Success: a partial month is flagged in the CSV', () {
    final csv = reportCsv(
      revenue: _revenue,
      comparison: _comparison(partial: true),
    );

    expect(csv, contains('period,partial_month,2026-10'));
    expect(csv, contains('period,partial_days,10'));
  });

  test('Failure: no period rows without a comparison', () {
    final csv = reportCsv(revenue: _revenue);

    expect(csv.contains('period,'), isFalse);
  });

  test('Success: periodBarHeights scales the tallest and keeps zero flat', () {
    expect(periodBarHeights([0, 34, 68], height: 68), [0, 34, 68]);
    expect(periodBarHeights([0, 0], height: 68), [0, 0]);
  });

  test(
    'Success: period PDF rows label the partial month with its day range',
    () {
      final rows = reportPeriodRows(
        l10n: l10n,
        comparison: _comparison(partial: true),
      );

      expect(rows.single.label, 'oct 2026 (1-10)');
      expect(rows.single.value, contains('n/d'));
    },
  );

  test('Security: the period PDF text has no em or en dash', () {
    final rows = reportPeriodRows(l10n: l10n, comparison: _comparison());

    for (final row in rows) {
      expect(row.label.contains('—'), isFalse);
      expect(row.label.contains('–'), isFalse);
      expect(row.value.contains('—'), isFalse);
      expect(row.value.contains('–'), isFalse);
      // Latin-1 (the built-in PDF font), not UTF-8: the middle dot is fine.
      expect(latin1.decode(latin1.encode(row.value)), row.value);
    }
  });

  test(
    'Success: buildRevenueReportPdf with a comparison returns bytes',
    () async {
      final bytes = await buildRevenueReportPdf(
        l10n: l10n,
        revenue: _revenue,
        headline: 'Reporte',
        comparison: _comparison(),
      );

      expect(bytes, isNotEmpty);
    },
  );
}
