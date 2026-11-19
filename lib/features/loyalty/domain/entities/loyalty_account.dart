import 'package:equatable/equatable.dart';

/// One member row of the admin list.
class LoyaltyAccount extends Equatable {
  const LoyaltyAccount({
    required this.plate,
    this.progress = 0,
    this.earnedTotal = 0,
    this.redeemedTotal = 0,
    this.rewardCount = 0,
    this.lastCountedDay,
  });

  final String plate;
  final int progress;
  final int earnedTotal;
  final int redeemedTotal;
  final int rewardCount;
  final DateTime? lastCountedDay;

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) => LoyaltyAccount(
    plate: json['plate'] as String? ?? '',
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    earnedTotal: (json['earned_total'] as num?)?.toInt() ?? 0,
    redeemedTotal: (json['redeemed_total'] as num?)?.toInt() ?? 0,
    rewardCount: (json['reward_count'] as num?)?.toInt() ?? 0,
    lastCountedDay: DateTime.tryParse(
      json['last_counted_day'] as String? ?? '',
    ),
  );

  @override
  List<Object?> get props => [
    plate,
    progress,
    earnedTotal,
    redeemedTotal,
    rewardCount,
    lastCountedDay,
  ];
}
