import '../domain/entities/revenue_report.dart';

/// Machine-readable CSV of the revenue report: one row per figure, raw numbers
/// (no currency symbols) so a spreadsheet can sum them. The comparison rows
/// are omitted when the previous window is unknown.
String reportCsv({
  required RevenueReport revenue,
  int? previousTotal,
  int? deltaPercent,
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
    for (final item in revenue.byPayment)
      ['by_payment', item.paymentMethod, item.amount],
    for (final item in revenue.byLot) ['by_lot', item.lotName, item.amount],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}
