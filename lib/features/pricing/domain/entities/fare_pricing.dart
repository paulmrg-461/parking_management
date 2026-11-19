import 'package:equatable/equatable.dart';

/// Typed view of `fare_quote.pricing` (the dynamic-pricing line of a fare).
class FarePricing extends Equatable {
  const FarePricing({
    this.ruleId,
    this.ruleName = '',
    this.kind = 'multiplier',
    this.multiplierBps = 10000,
    this.surchargeAmount = 0,
    this.delta = 0,
    this.clamped,
    this.lockedAt,
    this.source = 'checkin',
  });

  final int? ruleId;
  final String ruleName;
  final String kind;
  final int multiplierBps;
  final int surchargeAmount;

  /// Signed difference against the base fare (positive = surcharge).
  final int delta;
  final String? clamped;
  final DateTime? lockedAt;
  final String source;

  static FarePricing? fromMap(Map<String, Object?>? raw) {
    if (raw == null) {
      return null;
    }
    return FarePricing(
      ruleId: (raw['rule_id'] as num?)?.toInt(),
      ruleName: raw['rule_name'] as String? ?? '',
      kind: raw['kind'] as String? ?? 'multiplier',
      multiplierBps: (raw['multiplier_bps'] as num?)?.toInt() ?? 10000,
      surchargeAmount: (raw['surcharge_amount'] as num?)?.toInt() ?? 0,
      delta: (raw['delta'] as num?)?.toInt() ?? 0,
      clamped: raw['clamped'] as String?,
      lockedAt: DateTime.tryParse(raw['locked_at'] as String? ?? ''),
      source: raw['source'] as String? ?? 'checkin',
    );
  }

  /// Percentage as a signed number (20 for +20 %, -10 for -10 %).
  int get percentDelta => ((multiplierBps - 10000) / 100).round();

  @override
  List<Object?> get props => [
    ruleId,
    ruleName,
    kind,
    multiplierBps,
    surchargeAmount,
    delta,
    clamped,
    lockedAt,
    source,
  ];
}
