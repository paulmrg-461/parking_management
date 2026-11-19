import 'package:equatable/equatable.dart';

enum PriceTier { base, higher, lower }

PriceTier priceTierFromWire(String? value) => switch (value) {
  'higher' => PriceTier.higher,
  'lower' => PriceTier.lower,
  _ => PriceTier.base,
};

/// What an entry would cost right now (`pricing_quote`).
class PriceQuote extends Equatable {
  const PriceQuote({
    this.enabled = false,
    this.categoryId = 0,
    this.occupancyPct,
    this.ruleId,
    this.ruleName,
    this.multiplierBps = 10000,
    this.surchargeAmount = 0,
    this.hourlyBase = 0,
    this.hourlyCurrent = 0,
    this.tier = PriceTier.base,
  });

  final bool enabled;
  final int categoryId;
  final int? occupancyPct;
  final int? ruleId;
  final String? ruleName;
  final int multiplierBps;
  final int surchargeAmount;
  final int hourlyBase;
  final int hourlyCurrent;
  final PriceTier tier;

  bool get isSurge => tier == PriceTier.higher;

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    final rule = json['rule'] is Map
        ? Map<String, dynamic>.from(json['rule'] as Map)
        : const <String, dynamic>{};
    return PriceQuote(
      enabled: json['enabled'] as bool? ?? false,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      occupancyPct: (json['occupancy_pct'] as num?)?.toInt(),
      ruleId: (rule['id'] as num?)?.toInt(),
      ruleName: rule['name'] as String?,
      multiplierBps: (json['multiplier_bps'] as num?)?.toInt() ?? 10000,
      surchargeAmount: (json['surcharge_amount'] as num?)?.toInt() ?? 0,
      hourlyBase: (json['hourly_base'] as num?)?.toInt() ?? 0,
      hourlyCurrent: (json['hourly_current'] as num?)?.toInt() ?? 0,
      tier: priceTierFromWire(json['tier'] as String?),
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    categoryId,
    occupancyPct,
    ruleId,
    ruleName,
    multiplierBps,
    surchargeAmount,
    hourlyBase,
    hourlyCurrent,
    tier,
  ];
}
