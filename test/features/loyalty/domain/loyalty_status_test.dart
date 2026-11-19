import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_status.dart';

void main() {
  test('Success: parses the full plate status', () {
    final status = LoyaltyStatus.fromJson(const {
      'enabled': true,
      'plate': 'ABC123',
      'visits': 3,
      'required': 5,
      'next_visit': 4,
      'reward_count': 1,
      'reward_expires_at': '2026-12-01T12:00:00Z',
      'redeem_mode': 'operator',
      'counted_today': true,
    });

    expect(status.plate, 'ABC123');
    expect(status.visits, 3);
    expect(status.nextVisit, 4);
    expect(status.rewardCount, 1);
    expect(status.rewardExpiresAt, DateTime.utc(2026, 12, 1, 12));
    expect(status.redeemMode, LoyaltyRedeemMode.operator);
    expect(status.countedToday, isTrue);
  });

  test('Failure: missing keys parse as disabled zeros', () {
    final status = LoyaltyStatus.fromJson(const {});

    expect(status.enabled, isFalse);
    expect(status.visits, 0);
    expect(status.required, 0);
    expect(status.hasReward, isFalse);
  });

  test('Success: the last needed visit earns the reward', () {
    const status = LoyaltyStatus(
      enabled: true,
      visits: 4,
      required: 5,
      nextVisit: 5,
    );
    expect(status.earnsRewardNow, isTrue);

    const early = LoyaltyStatus(
      enabled: true,
      visits: 2,
      required: 5,
      nextVisit: 3,
    );
    expect(early.earnsRewardNow, isFalse);
  });

  test('Success: hasReward comes from the reward count', () {
    const withReward = LoyaltyStatus(enabled: true, rewardCount: 2);
    const without = LoyaltyStatus(enabled: true);
    expect(withReward.hasReward, isTrue);
    expect(without.hasReward, isFalse);
  });

  test('Security: a disabled status never claims a reward', () {
    const disabled = LoyaltyStatus.disabled;
    expect(disabled.earnsRewardNow, isFalse);
    expect(disabled.hasReward, isFalse);
  });
}
