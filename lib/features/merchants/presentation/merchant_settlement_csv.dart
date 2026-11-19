import '../domain/entities/merchant_settlement.dart';

/// Settlement rows as `section,label,value` CSV with raw integers (minor
/// units), like the revenue report export.
String merchantSettlementCsv(MerchantSettlement settlement) {
  final rows = <List<String>>[
    ['section', 'label', 'value'],
    ['range', 'from', _date(settlement.from)],
    ['range', 'to', _date(settlement.to)],
  ];
  for (final row in settlement.rows) {
    final name = row.name;
    rows
      ..add(['merchant', '$name: validations', '${row.validations}'])
      ..add(['merchant', '$name: applied', '${row.applied}'])
      ..add(['merchant', '$name: forfeited', '${row.forfeited}'])
      ..add(['merchant', '$name: revoked', '${row.revoked}'])
      ..add(['merchant', '$name: pending_now', '${row.pendingNow}'])
      ..add(['merchant', '$name: discounted_amount', '${row.discountedAmount}'])
      ..add(['merchant', '$name: amount_owed', '${row.amountOwed}'])
      ..add(['merchant', '$name: courtesy_amount', '${row.courtesyAmount}']);
  }
  final totals = settlement.totals;
  rows
    ..add(['total', 'validations', '${totals.validations}'])
    ..add(['total', 'applied', '${totals.applied}'])
    ..add(['total', 'forfeited', '${totals.forfeited}'])
    ..add(['total', 'revoked', '${totals.revoked}'])
    ..add(['total', 'discounted_amount', '${totals.discountedAmount}'])
    ..add(['total', 'amount_owed', '${totals.amountOwed}'])
    ..add(['total', 'courtesy_amount', '${totals.courtesyAmount}']);
  return rows.map(_line).join('\n');
}

String _line(List<String> cells) =>
    cells.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');

String _date(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
