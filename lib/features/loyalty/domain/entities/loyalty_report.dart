import 'package:equatable/equatable.dart';

class SkipCount extends Equatable {
  const SkipCount({required this.reason, this.count = 0});

  final String reason;
  final int count;

  factory SkipCount.fromJson(Map<String, dynamic> json) => SkipCount(
    reason: json['reason'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [reason, count];
}

class LoyaltyTopPlate extends Equatable {
  const LoyaltyTopPlate({
    required this.plate,
    this.counted = 0,
    this.redeemed = 0,
    this.discount = 0,
  });

  final String plate;
  final int counted;
  final int redeemed;
  final int discount;

  factory LoyaltyTopPlate.fromJson(Map<String, dynamic> json) =>
      LoyaltyTopPlate(
        plate: json['plate'] as String? ?? '',
        counted: (json['counted'] as num?)?.toInt() ?? 0,
        redeemed: (json['redeemed'] as num?)?.toInt() ?? 0,
        discount: (json['discount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [plate, counted, redeemed, discount];
}

/// Program impact in a business-date window.
class LoyaltyReport extends Equatable {
  const LoyaltyReport({
    required this.startDate,
    required this.endDate,
    this.enabled = false,
    this.members = 0,
    this.activeMembers = 0,
    this.counted = 0,
    this.skipped = 0,
    this.reversed = 0,
    this.skippedByReason = const [],
    this.earned = 0,
    this.redeemed = 0,
    this.expired = 0,
    this.rewardsReversed = 0,
    this.available = 0,
    this.discountGiven = 0,
    this.topPlates = const [],
  });

  final DateTime startDate;
  final DateTime endDate;
  final bool enabled;
  final int members;
  final int activeMembers;
  final int counted;
  final int skipped;
  final int reversed;
  final List<SkipCount> skippedByReason;
  final int earned;
  final int redeemed;
  final int expired;
  final int rewardsReversed;
  final int available;
  final int discountGiven;
  final List<LoyaltyTopPlate> topPlates;

  bool get hasVisits => counted + skipped + reversed > 0;

  static final LoyaltyReport empty = LoyaltyReport(
    startDate: DateTime(1970),
    endDate: DateTime(1970),
  );

  factory LoyaltyReport.fromJson(Map<String, dynamic> json) {
    final visits = json['visits'] is Map
        ? Map<String, dynamic>.from(json['visits'] as Map)
        : const <String, dynamic>{};
    final rewards = json['rewards'] is Map
        ? Map<String, dynamic>.from(json['rewards'] as Map)
        : const <String, dynamic>{};
    return LoyaltyReport(
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      enabled: json['enabled'] as bool? ?? false,
      members: (json['members'] as num?)?.toInt() ?? 0,
      activeMembers: (json['active_members'] as num?)?.toInt() ?? 0,
      counted: (visits['counted'] as num?)?.toInt() ?? 0,
      skipped: (visits['skipped'] as num?)?.toInt() ?? 0,
      reversed: (visits['reversed'] as num?)?.toInt() ?? 0,
      skippedByReason: [
        for (final item in (visits['skipped_by_reason'] as List? ?? const []))
          if (item is Map)
            SkipCount.fromJson(Map<String, dynamic>.from(item)),
      ],
      earned: (rewards['earned'] as num?)?.toInt() ?? 0,
      redeemed: (rewards['redeemed'] as num?)?.toInt() ?? 0,
      expired: (rewards['expired'] as num?)?.toInt() ?? 0,
      rewardsReversed: (rewards['reversed'] as num?)?.toInt() ?? 0,
      available: (rewards['available'] as num?)?.toInt() ?? 0,
      discountGiven: (json['discount_given'] as num?)?.toInt() ?? 0,
      topPlates: [
        for (final item in (json['top_plates'] as List? ?? const []))
          if (item is Map)
            LoyaltyTopPlate.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  static DateTime _date(Object? raw) =>
      DateTime.tryParse(raw as String? ?? '') ?? DateTime(1970);

  @override
  List<Object?> get props => [
    startDate,
    endDate,
    enabled,
    members,
    activeMembers,
    counted,
    skipped,
    reversed,
    skippedByReason,
    earned,
    redeemed,
    expired,
    rewardsReversed,
    available,
    discountGiven,
    topPlates,
  ];
}
