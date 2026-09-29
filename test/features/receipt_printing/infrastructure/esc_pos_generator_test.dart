import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/receipt_data.dart';
import 'package:parking_management/features/receipt_printing/infrastructure/esc_pos_generator.dart';

String _decode(List<int> bytes) => String.fromCharCodes(
  bytes.where((b) => b >= 0x20 && b < 0x7F),
);

void main() {
  test('Success: check-out receipt contains plate, duration, amount and ticket', () {
    final bytes = const EscPosGenerator().build(
      ReceiptData(
        kind: ReceiptKind.checkOut,
        plate: 'ABC123',
        entryTime: DateTime(2026, 1, 1, 8, 30),
        exitTime: DateTime(2026, 1, 1, 11, 45),
        amountCharged: 12500,
        ticketNumber: 'TCK-000042',
      ),
    );

    final text = _decode(bytes);
    expect(text, contains('ABC123'));
    expect(text, contains('3 h 15 min'));
    expect(text, contains('12.500'));
    expect(text, contains('TCK-000042'));
  });

  test('Failure: check-in receipt omits the amount and includes photos', () {
    final bytes = const EscPosGenerator().build(
      ReceiptData(
        kind: ReceiptKind.checkIn,
        plate: 'XYZ999',
        entryTime: DateTime(2026, 1, 1, 9, 0),
        photoCount: 2,
      ),
    );

    final text = _decode(bytes);
    expect(text, contains('XYZ999'));
    expect(text, contains('Fotos: 2'));
    expect(text, isNot(contains('Total')));
  });

  test('Security: pending-sync receipt never prints the amount or ticket', () {
    final bytes = const EscPosGenerator().build(
      ReceiptData(
        kind: ReceiptKind.checkOut,
        plate: 'ABC123',
        entryTime: DateTime(2026, 1, 1, 8, 30),
        exitTime: DateTime(2026, 1, 1, 9, 30),
        amountCharged: 8000,
        ticketNumber: 'TCK-000043',
        pendingSync: true,
      ),
    );

    final text = _decode(bytes);
    expect(text, contains('PENDIENTE DE SINCRONIZAR'));
    expect(text, isNot(contains('8.000')));
    expect(text, isNot(contains('Total')));
    expect(text, isNot(contains('TCK-000043')));
  });
}
