import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_offer.dart';

void main() {
  test('Success: parses the public offer with the masked plate', () {
    final offer = PassRenewalOffer.fromJson(const {
      'status': 'open',
      'lot_name': 'Central',
      'plate_masked': 'ABC***',
      'period_start': '2026-12-01',
      'period_end': '2026-12-31',
      'amount': 80000,
      'currency': 'COP',
      'expires_at': '2026-11-30T12:00:00.000Z',
      'payment_links_enabled': true,
    });

    expect(offer.status, PassRenewalStatus.open);
    expect(offer.plateMasked, 'ABC***');
    expect(offer.amount, 80000);
    expect(offer.paymentLinksEnabled, isTrue);
    expect(offer.renewalPeriodEnd, isNull);
  });

  test('Success: a paid offer carries the created period', () {
    final offer = PassRenewalOffer.fromJson(const {
      'status': 'paid',
      'period_start': '2026-12-01',
      'period_end': '2026-12-31',
      'amount': 80000,
      'renewal_period_start': '2026-12-01',
      'renewal_period_end': '2026-12-31',
    });

    expect(offer.status.isPaid, isTrue);
    expect(offer.renewalPeriodStart, DateTime(2026, 12, 1));
  });

  test('Failure: unknown or missing keys fall back safely', () {
    final offer = PassRenewalOffer.fromJson(const {
      'status': 'weird',
      'period_start': 'not-a-date',
    });

    expect(offer.status, PassRenewalStatus.open);
    expect(offer.amount, 0);
    expect(offer.paymentLinksEnabled, isFalse);
  });
}
