import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';

void main() {
  test('Success: toJson uses the rpc keys', () {
    const settings = LoyaltySettings(
      enabled: true,
      visitsRequired: 4,
      rewardKind: LoyaltyRewardKind.fixedAmount,
      rewardFixedAmount: 5000,
      minAmount: 3000,
      minMinutes: 30,
      redeemMode: LoyaltyRedeemMode.operator,
      stackWithMerchant: false,
      rewardValidDays: 30,
    );

    final json = settings.toJson();
    expect(json['enabled'], isTrue);
    expect(json['visits_required'], 4);
    expect(json['reward_kind'], 'fixed_amount');
    expect(json['reward_fixed_amount'], 5000);
    expect(json['min_amount'], 3000);
    expect(json['min_minutes'], 30);
    expect(json['redeem_mode'], 'operator');
    expect(json['stack_with_merchant'], isFalse);
    expect(json['reward_valid_days'], 30);
  });

  test('Success: a missing cap is serialised explicitly as null', () {
    const settings = LoyaltySettings();
    expect(settings.toJson().containsKey('reward_max_amount'), isTrue);
    expect(settings.toJson()['reward_max_amount'], isNull);
  });

  test('Failure: an unknown kind falls back to free stay', () {
    final settings = LoyaltySettings.fromJson(const {
      'reward_kind': 'bogus',
      'redeem_mode': 'bogus',
    });
    expect(settings.rewardKind, LoyaltyRewardKind.freeStay);
    expect(settings.redeemMode, LoyaltyRedeemMode.auto);
  });

  test('Success: fromJson reads the server keys', () {
    final settings = LoyaltySettings.fromJson(const {
      'enabled': true,
      'visits_required': 6,
      'reward_kind': 'fixed_amount',
      'reward_max_amount': 9000,
      'reward_fixed_amount': 2000,
      'min_amount': 3000,
      'min_minutes': 60,
      'redeem_mode': 'operator',
      'stack_with_merchant': false,
      'reward_valid_days': 45,
    });

    expect(settings.visitsRequired, 6);
    expect(settings.rewardMaxAmount, 9000);
    expect(settings.minMinutes, 60);
    expect(settings.stackWithMerchant, isFalse);
    expect(settings.rewardValidDays, 45);
  });
}
