import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/receipt_data.dart';
import 'package:parking_management/features/receipt_printing/infrastructure/receipt_line_builder.dart';

String _joinLines(Iterable<String?> contents) => contents
    .whereType<String>()
    .join('\n');

void main() {
  test('check-out receipt lines contain plate, duration, amount and ticket', () {
    final lines = const ReceiptLineBuilder().build(
      ReceiptData(
        kind: ReceiptKind.checkOut,
        plate: 'ABC123',
        entryTime: DateTime(2026, 1, 1, 8, 30),
        exitTime: DateTime(2026, 1, 1, 11, 45),
        amountCharged: 12500,
        ticketNumber: 'TCK-000042',
      ),
    );

    final text = _joinLines([for (final line in lines) line.content]);
    expect(text, contains('ABC123'));
    expect(text, contains('3 h 15 min'));
    expect(text, contains('12.500'));
    expect(text, contains('TCK-000042'));
  });

  test('check-in receipt lines omit the amount and include photos', () {
    final lines = const ReceiptLineBuilder().build(
      ReceiptData(
        kind: ReceiptKind.checkIn,
        plate: 'XYZ999',
        entryTime: DateTime(2026, 1, 1, 9, 0),
        photoCount: 2,
      ),
    );

    final text = _joinLines([for (final line in lines) line.content]);
    expect(text, contains('XYZ999'));
    expect(text, isNot(contains('Total')));
  });
}
