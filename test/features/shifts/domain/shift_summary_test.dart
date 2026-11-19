import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/shifts/domain/entities/shift_summary.dart';

void main() {
  test('Success: the summary parses the online sales row', () {
    final shift = ShiftSummary.fromJson(const {
      'id': 1,
      'operator_id': 2,
      'opened_at': '2026-11-17T08:00:00.000Z',
      'opening_float': 10000,
      'expected_cash': 15000,
      'revenue': 20000,
      'cash_sales': 10000,
      'online_sales': 10000,
    });

    expect(shift.onlineSales, 10000);
    expect(shift.revenue, 20000);
  });

  test('Failure: an older server without the row keeps zero', () {
    final shift = ShiftSummary.fromJson(const {
      'id': 1,
      'operator_id': 2,
      'opened_at': '2026-11-17T08:00:00.000Z',
      'expected_cash': 0,
    });

    expect(shift.onlineSales, 0);
  });
}
