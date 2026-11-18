import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/fare/fare_adjustment.dart';
import 'package:parking_management/core/fare/fare_quote.dart';

void main() {
  test('Success: parses the full quote with merchant lines', () {
    final quote = FareQuote.fromJson(const {
      'session_id': 12,
      'base_amount': 9000,
      'gross': 9000,
      'has_pass': false,
      'lost_ticket': false,
      'adjustments': [
        {
          'type': 'merchant',
          'ref_id': 3,
          'label': 'Cafe Uno',
          'kind': 'percentage',
          'amount': 4500,
        },
      ],
      'adjustments_total': 4500,
      'discount_amount': 0,
      'amount_due': 4500,
      'pricing': null,
      'reward': null,
    });

    expect(quote.baseAmount, 9000);
    expect(quote.gross, 9000);
    expect(quote.adjustments, hasLength(1));
    expect(quote.adjustments.single.type, FareAdjustmentType.merchant);
    expect(quote.adjustments.single.refId, 3);
    expect(quote.adjustmentsTotal, 4500);
    expect(quote.amountDue, 4500);
    expect(quote.pricing, isNull);
  });

  test('Failure: unknown and missing keys default safely', () {
    final quote = FareQuote.fromJson(const {
      'session_id': 7,
      'adjustments': [
        {'type': 'loyalty', 'amount': 100},
      ],
    });

    expect(quote.gross, 0);
    expect(quote.adjustments.single.type, FareAdjustmentType.unknown);
    expect(quote.adjustments.single.amount, 100);
    expect(quote.amountDue, 0);
  });

  test('Success: amount due equals gross minus the lines and discount', () {
    final quote = FareQuote.fromJson(const {
      'session_id': 1,
      'base_amount': 9000,
      'gross': 9000,
      'adjustments_total': 4500,
      'discount_amount': 500,
      'amount_due': 4000,
    });

    expect(
      quote.amountDue,
      quote.gross - quote.adjustmentsTotal - quote.discountAmount,
    );
  });
}
