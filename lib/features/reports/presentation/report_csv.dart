import '../domain/entities/hourly_traffic.dart';
import '../domain/entities/period_comparison.dart';
import '../domain/entities/revenue_report.dart';

/// Machine-readable CSV of the revenue report: one row per figure, raw numbers
/// (no currency symbols) so a spreadsheet can sum them. The comparison rows
/// are omitted when the previous window is unknown.
String reportCsv({
  required RevenueReport revenue,
  int? previousTotal,
  int? deltaPercent,
  HourlyTraffic? hourly,
  PeriodComparison? comparison,
}) {
  String cell(Object? value) {
    final text = (value ?? '').toString();
    return text.contains(RegExp('[",\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  final rows = <List<Object?>>[
    ['section', 'label', 'value'],
    ['summary', 'total', revenue.total],
    if (revenue.totalDiscounts > 0)
      ['summary', 'discounts', revenue.totalDiscounts],
    if (revenue.discountedSessions > 0)
      ['summary', 'discounted_sessions', revenue.discountedSessions],
    if (revenue.passRevenue > 0)
      ['summary', 'pass_revenue', revenue.passRevenue],
    if (previousTotal != null && deltaPercent != null) ...[
      ['comparison', 'variation_percent', deltaPercent],
      ['comparison', 'previous_total', previousTotal],
    ],
    for (final item in revenue.byDay) ['by_day', day(item.date), item.amount],
    for (final item in revenue.byCategory)
      ['by_category', item.categoryName, item.amount],
    if (comparison != null && !comparison.isEmpty) ...[
      ['period', 'as_of', _day(comparison.asOf ?? revenue.endDate)],
      if (comparison.latest?.isPartial ?? false) ...[
        ['period', 'partial_month', comparison.latest!.monthKey],
        ['period', 'partial_days', comparison.latest!.current.days],
      ],
      for (final bucket in comparison.buckets)
        for (final metric in _periodCsvMetrics) ...[
          [
            'period_${metric.$1}',
            bucket.monthKey,
            bucket.current.valueOf(metric.$2),
          ],
          [
            'period_${metric.$1}_prev_month',
            bucket.monthKey,
            bucket.previousMonth.valueOf(metric.$2),
          ],
          [
            'period_${metric.$1}_prev_year',
            bucket.monthKey,
            bucket.previousYear.valueOf(metric.$2),
          ],
        ],
    ],
    for (final item in revenue.byPayment)
      ['by_payment', item.paymentMethod, item.amount],
    for (final item in revenue.byLot) ['by_lot', item.lotName, item.amount],
    for (final point in hourly?.hours ?? const <HourlyTrafficPoint>[])
      if (point.total > 0) ...[
        ['hourly_entries', point.timeLabel, point.entries],
        ['hourly_exits', point.timeLabel, point.exits],
      ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}

/// Raw metric keys for the CSV; the order is the one the spreadsheet expects.
const _periodCsvMetrics = <(String, PeriodMetric)>[
  ('revenue', PeriodMetric.revenue),
  ('entries', PeriodMetric.entries),
  ('exits', PeriodMetric.exits),
  ('avg_ticket', PeriodMetric.avgTicket),
  ('avg_stay_minutes', PeriodMetric.avgStay),
  ('pass_revenue', PeriodMetric.passRevenue),
  ('reservations', PeriodMetric.reservations),
];

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
