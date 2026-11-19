import 'package:equatable/equatable.dart';

import 'loyalty_settings.dart';

/// The operator read of one plate (counts only, never the visit history).
class LoyaltyStatus extends Equatable {
  const LoyaltyStatus({
    this.enabled = false,
    this.plate = '',
    this.visits = 0,
    this.required = 0,
    this.nextVisit = 0,
    this.rewardCount = 0,
    this.rewardExpiresAt,
    this.redeemMode = LoyaltyRedeemMode.auto,
    this.countedToday = false,
  });

  final bool enabled;
  final String plate;

  /// Current progress inside the threshold (0 .. required - 1).
  final int visits;
  final int required;

  /// The visit being registered (`visits + 1`).
  final int nextVisit;
  final int rewardCount;
  final DateTime? rewardExpiresAt;
  final LoyaltyRedeemMode redeemMode;
  final bool countedToday;

  bool get hasReward => rewardCount > 0;

  /// The visit being registered is the one that earns the reward.
  bool get earnsRewardNow => enabled && nextVisit >= required && required > 0;

  static const disabled = LoyaltyStatus();

  factory LoyaltyStatus.fromJson(Map<String, dynamic> json) => LoyaltyStatus(
    enabled: json['enabled'] as bool? ?? false,
    plate: json['plate'] as String? ?? '',
    visits: (json['visits'] as num?)?.toInt() ?? 0,
    required: (json['required'] as num?)?.toInt() ?? 0,
    nextVisit: (json['next_visit'] as num?)?.toInt() ?? 0,
    rewardCount: (json['reward_count'] as num?)?.toInt() ?? 0,
    rewardExpiresAt: DateTime.tryParse(
      json['reward_expires_at'] as String? ?? '',
    ),
    redeemMode: LoyaltyRedeemMode.parse(json['redeem_mode'] as String?),
    countedToday: json['counted_today'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    enabled,
    plate,
    visits,
    required,
    nextVisit,
    rewardCount,
    rewardExpiresAt,
    redeemMode,
    countedToday,
  ];
}
