import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_portal.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_settlement.dart';

void main() {
  test('Success: parses every benefit kind', () {
    Merchant parse(String kind, int value) => Merchant.fromJson({
      'id': 1,
      'name': 'X',
      'benefit_kind': kind,
      'benefit_value': value,
      'billing_mode': 'merchant_paid',
    });

    expect(parse('free_minutes', 30).kind, MerchantBenefitKind.freeMinutes);
    expect(parse('percentage', 10).kind, MerchantBenefitKind.percentage);
    expect(parse('fixed_amount', 5000).kind, MerchantBenefitKind.fixedAmount);
  });

  test('Failure: an unknown kind falls back to percentage', () {
    final merchant = Merchant.fromJson(const {
      'id': 1,
      'name': 'X',
      'benefit_kind': 'cashback',
      'benefit_value': 10,
    });
    expect(merchant.kind, MerchantBenefitKind.percentage);
    expect(merchant.billingMode, MerchantBillingMode.merchantPaid);
  });

  test('Success: credentials build the absolute link when APP_URL exists', () {
    const credentials = MerchantCredentials(
      merchantId: 2,
      pin: '123456',
      token: 'abc',
      linkPath: '/validate?m=abc',
    );

    expect(
      credentials.linkFor(Uri.parse('https://parking.test'))?.toString(),
      'https://parking.test/validate?m=abc',
    );
    expect(credentials.linkFor(null), isNull);
  });

  test('Success: parses the settlement rows and totals', () {
    final settlement = MerchantSettlement.fromJson(const {
      'from': '2026-11-01',
      'to': '2026-11-30',
      'merchants': [
        {
          'merchant_id': 1,
          'name': 'Cafe Uno',
          'billing_mode': 'merchant_paid',
          'benefit_kind': 'percentage',
          'validations': 3,
          'applied': 2,
          'forfeited': 1,
          'revoked': 0,
          'pending_now': 0,
          'discounted_amount': 9000,
          'amount_owed': 9000,
          'courtesy_amount': 0,
        },
      ],
      'totals': {
        'validations': 3,
        'applied': 2,
        'forfeited': 1,
        'revoked': 0,
        'discounted_amount': 9000,
        'amount_owed': 9000,
        'courtesy_amount': 0,
      },
    });

    expect(settlement.rows.single.name, 'Cafe Uno');
    expect(settlement.rows.single.amountOwed, 9000);
    expect(settlement.totals.validations, 3);
    expect(settlement.hasActivity, isTrue);
  });

  test('Security: a public portal never exposes the PIN', () {
    final portal = MerchantPortal.fromJson(const {
      'merchant_name': 'Cafe Uno',
      'benefit_kind': 'percentage',
      'benefit_value': 10,
      'lot_name': 'Central',
      'pin': '123456',
    });

    expect(portal.merchantName, 'Cafe Uno');
    expect(portal.props, isNot(contains('123456')));
  });
}
