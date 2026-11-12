import 'dart:convert';

import '../domain/entities/reservation.dart';

/// CSV of the reservations board: one row per hold with the code the customer
/// shows, the plate, the category, the expiry, the contact and where it came
/// from. Times are ISO-8601 so a spreadsheet can sort them; the phone is kept
/// as a plain string (Excel would eat the leading zero of a local number).
String reservationsCsv(Iterable<Reservation> reservations) {
  String cell(Object? value) {
    final text = (value ?? '').toString();
    return text.contains(RegExp('[",\n;]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  final rows = <List<Object?>>[
    [
      'code',
      'plate',
      'category',
      'reserved_until',
      'customer',
      'phone',
      'source',
      'status',
      'in_grace',
      'notes',
    ],
    for (final hold in reservations)
      [
        hold.id,
        hold.plate,
        hold.categoryName,
        hold.reservedUntil.toUtc().toIso8601String(),
        hold.customerName ?? '',
        hold.customerPhone ?? '',
        hold.source,
        hold.status,
        hold.inGrace ? 'yes' : 'no',
        hold.notes ?? '',
      ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\n');
}

/// Same text, ready for a file name (`reservas-2026-11-10.csv`).
String reservationsCsvFileName(DateTime day) =>
    'reservas-${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}.csv';

/// Bytes for sharing/downloading; the BOM keeps Excel from mangling accents.
List<int> reservationsCsvBytes(Iterable<Reservation> reservations) =>
    utf8.encode('\uFEFF${reservationsCsv(reservations)}');
