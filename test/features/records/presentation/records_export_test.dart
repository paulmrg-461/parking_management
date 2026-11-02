import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/money/currency.dart';
import 'package:parking_management/core/money/money.dart';
import 'package:parking_management/features/records/presentation/records_csv.dart';
import 'package:parking_management/features/records/presentation/records_pdf.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../../../helpers/fake_record_repository.dart';

void main() {
  test('Success: CSV has a header and one row per record', () {
    final csv = recordsCsv([
      sampleRecord(id: 1, plate: 'ABC123'),
      sampleRecord(id: 2, plate: 'XYZ999', status: 'open', amountCharged: 0),
    ]);

    final lines = csv.split('\n');
    expect(lines.first, 'plate,category,entry,exit,minutes,amount,status,ticket');
    expect(lines, hasLength(3));
    expect(lines[1], contains('ABC123'));
    expect(lines[1], contains('5000'));
    expect(lines[2], contains('open'));
  });

  test('Success: a USD site exports amounts in major units', () {
    Money.configure(Currency.usd);
    addTearDown(() => Money.configure(Currency.cop));

    final csv = recordsCsv([
      sampleRecord(id: 1, plate: 'ABC123', amountCharged: 5050),
    ]);

    expect(csv, contains(',50.50,'));
  });

  test('Security: CSV quotes values with commas or quotes', () {
    final csv = recordsCsv([sampleRecord(id: 1, plate: 'A,B"C')]);

    expect(csv, contains('"A,B""C"'));
  });

  test('Success: the PDF is a real document', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    final bytes = await buildRecordsPdf(
      l10n: l10n,
      records: [sampleRecord(id: 1, plate: 'ABC123')],
      plate: 'ABC123',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
