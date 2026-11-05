import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/infrastructure/models/check_out_receipt_dto.dart';
import 'package:parking_management/features/check_out/infrastructure/models/open_session_dto.dart';

Map<String, dynamic> _receiptJson([Map<String, dynamic> extra = const {}]) => {
  'id': 9,
  'plate': 'ABC123',
  'entry_time': '2026-01-01T10:00:00.000Z',
  'exit_time': '2026-01-01T12:00:00.000Z',
  'amount_charged': 8000,
  'ticket_number': 'T-1',
  ...extra,
};

void main() {
  group('CheckOutReceiptDto.toDomain', () {
    test('Success: carries card type, cash received and change', () {
      final receipt = CheckOutReceiptDto.fromJson(
        _receiptJson({
          'payment_method': 'cash',
          'card_type': 'debit',
          'cash_received': 10000,
          'cash_change': 2000,
        }),
      ).toDomain();

      expect(receipt.cardType, 'debit');
      expect(receipt.cashReceived, 10000);
      expect(receipt.cashChange, 2000);
    });

    test('Failure: an older server without the cash fields maps to null', () {
      final receipt = CheckOutReceiptDto.fromJson(_receiptJson()).toDomain();

      expect(receipt.cardType, isNull);
      expect(receipt.cashReceived, isNull);
      expect(receipt.cashChange, isNull);
    });

    test('Security: receipts differing only in cash change are not equal', () {
      CheckOutReceipt withChange(int change) => CheckOutReceipt(
        id: 1,
        plate: 'ABC123',
        entryTime: DateTime.utc(2026),
        exitTime: DateTime.utc(2026),
        amountCharged: 8000,
        ticketNumber: 'T-1',
        cashReceived: 10000,
        cashChange: change,
      );

      expect(withChange(2000), isNot(withChange(0)));
    });
  });

  group('OpenSessionDto.toDomain', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 3,
      'vehicle_id': 7,
      'entry_time': '2026-01-01T10:00:00.000Z',
      ...extra,
    };

    test('Success: carries plate, photo count and left keys', () {
      final session = OpenSessionDto.fromJson(
        json({'plate': 'XYZ987', 'photo_count': 2, 'left_keys': true}),
      ).toDomain();

      expect(session.plate, 'XYZ987');
      expect(session.photoCount, 2);
      expect(session.leftKeys, isTrue);
    });

    test('Failure: missing optional columns fall back to defaults', () {
      final session = OpenSessionDto.fromJson(json({})).toDomain();

      expect(session.plate, '');
      expect(session.photoCount, 0);
      expect(session.leftKeys, isFalse);
    });
  });
}
