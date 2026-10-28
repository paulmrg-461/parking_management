import '../domain/entities/session_record.dart';

/// Machine-readable CSV of the records log (RFC 4180 quoting, raw amounts).
String recordsCsv(List<SessionRecord> records) {
  String cell(Object? value) {
    final text = (value ?? '').toString();
    return text.contains(RegExp('[",\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  String stamp(DateTime? value) => value == null
      ? ''
      : '${value.toLocal().year.toString().padLeft(4, '0')}-'
            '${value.toLocal().month.toString().padLeft(2, '0')}-'
            '${value.toLocal().day.toString().padLeft(2, '0')} '
            '${value.toLocal().hour.toString().padLeft(2, '0')}:'
            '${value.toLocal().minute.toString().padLeft(2, '0')}';

  final rows = <List<Object?>>[
    [
      'plate',
      'category',
      'entry',
      'exit',
      'minutes',
      'amount',
      'status',
      'ticket',
    ],
    for (final record in records)
      [
        record.plate,
        record.category,
        stamp(record.entryTime),
        stamp(record.exitTime),
        record.duration.inMinutes,
        record.amountCharged,
        record.status,
        record.ticketNumber ?? '',
      ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}
