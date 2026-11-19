import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_report.dart';

void main() {
  test('Success: parses the report and its nested sections', () {
    final report = LoyaltyReport.fromJson(const {
      'start_date': '2026-11-01',
      'end_date': '2026-11-30',
      'enabled': true,
      'members': 128,
      'active_members': 57,
      'visits': {
        'counted': 410,
        'skipped': 96,
        'reversed': 2,
        'skipped_by_reason': [
          {'reason': 'same_day', 'count': 40},
        ],
      },
      'rewards': {
        'earned': 81,
        'redeemed': 63,
        'expired': 4,
        'reversed': 1,
        'available': 30,
      },
      'discount_given': 189000,
      'top_plates': [
        {'plate': 'ABC123', 'counted': 9, 'redeemed': 1, 'discount': 12000},
      ],
    });

    expect(report.members, 128);
    expect(report.activeMembers, 57);
    expect(report.counted, 410);
    expect(report.skippedByReason.single.reason, 'same_day');
    expect(report.earned, 81);
    expect(report.available, 30);
    expect(report.discountGiven, 189000);
    expect(report.topPlates.single.plate, 'ABC123');
    expect(report.hasVisits, isTrue);
  });

  test('Success: empty has zeros', () {
    final report = LoyaltyReport.empty;
    expect(report.members, 0);
    expect(report.counted, 0);
    expect(report.discountGiven, 0);
    expect(report.topPlates, isEmpty);
    expect(report.hasVisits, isFalse);
  });

  test('Failure: missing sections parse as zeros', () {
    final report = LoyaltyReport.fromJson(const {
      'start_date': '2026-11-01',
      'end_date': '2026-11-01',
    });
    expect(report.members, 0);
    expect(report.skippedByReason, isEmpty);
  });
}
