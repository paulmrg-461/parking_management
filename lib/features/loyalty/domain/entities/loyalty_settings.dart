import 'package:equatable/equatable.dart';

/// How a reward is granted at the window.
enum LoyaltyRedeemMode {
  auto,
  operator;

  String get wire => name;

  static LoyaltyRedeemMode parse(String? value) =>
      value == 'operator' ? LoyaltyRedeemMode.operator : LoyaltyRedeemMode.auto;
}

/// What a reward is worth.
enum LoyaltyRewardKind {
  freeStay,
  fixedAmount;

  String get wire => this == LoyaltyRewardKind.fixedAmount
      ? 'fixed_amount'
      : 'free_stay';

  static LoyaltyRewardKind parse(String? value) =>
      value == 'fixed_amount'
      ? LoyaltyRewardKind.fixedAmount
      : LoyaltyRewardKind.freeStay;
}

/// The lot program: threshold, reward value, anti-abuse floors and mode.
class LoyaltySettings extends Equatable {
  const LoyaltySettings({
    this.enabled = false,
    this.visitsRequired = 5,
    this.rewardKind = LoyaltyRewardKind.freeStay,
    this.rewardMaxAmount,
    this.rewardFixedAmount = 0,
    this.minAmount = 0,
    this.minMinutes = 0,
    this.redeemMode = LoyaltyRedeemMode.auto,
    this.stackWithMerchant = true,
    this.rewardValidDays = 90,
  });

  final bool enabled;
  final int visitsRequired;
  final LoyaltyRewardKind rewardKind;
  final int? rewardMaxAmount;
  final int rewardFixedAmount;
  final int minAmount;
  final int minMinutes;
  final LoyaltyRedeemMode redeemMode;
  final bool stackWithMerchant;
  final int rewardValidDays;

  LoyaltySettings copyWith({
    bool? enabled,
    int? visitsRequired,
    LoyaltyRewardKind? rewardKind,
    int? rewardMaxAmount,
    bool clearMaxAmount = false,
    int? rewardFixedAmount,
    int? minAmount,
    int? minMinutes,
    LoyaltyRedeemMode? redeemMode,
    bool? stackWithMerchant,
    int? rewardValidDays,
  }) => LoyaltySettings(
    enabled: enabled ?? this.enabled,
    visitsRequired: visitsRequired ?? this.visitsRequired,
    rewardKind: rewardKind ?? this.rewardKind,
    rewardMaxAmount: clearMaxAmount
        ? null
        : (rewardMaxAmount ?? this.rewardMaxAmount),
    rewardFixedAmount: rewardFixedAmount ?? this.rewardFixedAmount,
    minAmount: minAmount ?? this.minAmount,
    minMinutes: minMinutes ?? this.minMinutes,
    redeemMode: redeemMode ?? this.redeemMode,
    stackWithMerchant: stackWithMerchant ?? this.stackWithMerchant,
    rewardValidDays: rewardValidDays ?? this.rewardValidDays,
  );

  factory LoyaltySettings.fromJson(Map<String, dynamic> json) =>
      LoyaltySettings(
        enabled: json['enabled'] as bool? ?? false,
        visitsRequired: (json['visits_required'] as num?)?.toInt() ?? 5,
        rewardKind: LoyaltyRewardKind.parse(json['reward_kind'] as String?),
        rewardMaxAmount: (json['reward_max_amount'] as num?)?.toInt(),
        rewardFixedAmount:
            (json['reward_fixed_amount'] as num?)?.toInt() ?? 0,
        minAmount: (json['min_amount'] as num?)?.toInt() ?? 0,
        minMinutes: (json['min_minutes'] as num?)?.toInt() ?? 0,
        redeemMode: LoyaltyRedeemMode.parse(json['redeem_mode'] as String?),
        stackWithMerchant: json['stack_with_merchant'] as bool? ?? true,
        rewardValidDays: (json['reward_valid_days'] as num?)?.toInt() ?? 90,
      );

  /// `set_loyalty_settings` payload. An absent cap is sent explicitly as null.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'visits_required': visitsRequired,
    'reward_kind': rewardKind.wire,
    'reward_max_amount': rewardMaxAmount,
    'reward_fixed_amount': rewardFixedAmount,
    'min_amount': minAmount,
    'min_minutes': minMinutes,
    'redeem_mode': redeemMode.wire,
    'stack_with_merchant': stackWithMerchant,
    'reward_valid_days': rewardValidDays,
  };

  @override
  List<Object?> get props => [
    enabled,
    visitsRequired,
    rewardKind,
    rewardMaxAmount,
    rewardFixedAmount,
    minAmount,
    minMinutes,
    redeemMode,
    stackWithMerchant,
    rewardValidDays,
  ];
}
