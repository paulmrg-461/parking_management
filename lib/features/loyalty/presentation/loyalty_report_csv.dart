import '../domain/entities/loyalty_report.dart';

/// Machine-readable CSV: one row per figure, raw integers (no symbols), so a
/// spreadsheet can sum them. Columns: `section,label,value`.
String loyaltyReportCsv(LoyaltyReport report) {
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
    ['period', 'start', day(report.startDate)],
    ['period', 'end', day(report.endDate)],
    ['summary', 'members', report.members],
    ['summary', 'active_members', report.activeMembers],
    ['visits', 'counted', report.counted],
    ['visits', 'skipped', report.skipped],
    ['visits', 'reversed', report.reversed],
    for (final item in report.skippedByReason)
      ['skip_reason', item.reason, item.count],
    ['rewards', 'earned', report.earned],
    ['rewards', 'redeemed', report.redeemed],
    ['rewards', 'expired', report.expired],
    ['rewards', 'reversed', report.rewardsReversed],
    ['rewards', 'available', report.available],
    ['summary', 'discount_given', report.discountGiven],
    for (final item in report.topPlates) ...[
      ['top_plate_counted', item.plate, item.counted],
      ['top_plate_redeemed', item.plate, item.redeemed],
      ['top_plate_discount', item.plate, item.discount],
    ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}
