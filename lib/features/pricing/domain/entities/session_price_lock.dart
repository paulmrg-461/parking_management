import 'package:equatable/equatable.dart';

/// The stored lock of a session or a public hold (`pricing_session_lock` /
/// `public_reservation_pricing`).
class SessionPriceLock extends Equatable {
  const SessionPriceLock({
    this.sessionId,
    this.ruleId,
    this.ruleName = '',
    this.kind = 'multiplier',
    this.multiplierBps = 10000,
    this.surchargeAmount = 0,
    this.hourlyBase = 0,
    this.hourlyLocked = 0,
    this.occupancyPct,
    this.lockedAt,
    this.source = 'checkin',
  });

  final int? sessionId;
  final int? ruleId;
  final String ruleName;
  final String kind;
  final int multiplierBps;
  final int surchargeAmount;
  final int hourlyBase;
  final int hourlyLocked;
  final int? occupancyPct;
  final DateTime? lockedAt;
  final String source;

  factory SessionPriceLock.fromJson(Map<String, dynamic> json) =>
      SessionPriceLock(
        sessionId: (json['session_id'] as num?)?.toInt(),
        ruleId: (json['rule_id'] as num?)?.toInt(),
        ruleName: json['rule_name'] as String? ?? '',
        kind: json['kind'] as String? ?? 'multiplier',
        multiplierBps: (json['multiplier_bps'] as num?)?.toInt() ?? 10000,
        surchargeAmount: (json['surcharge_amount'] as num?)?.toInt() ?? 0,
        hourlyBase: (json['hourly_base'] as num?)?.toInt() ?? 0,
        hourlyLocked: (json['hourly_locked'] as num?)?.toInt() ?? 0,
        occupancyPct: (json['occupancy_pct'] as num?)?.toInt(),
        lockedAt: DateTime.tryParse(json['locked_at'] as String? ?? ''),
        source: json['source'] as String? ?? 'checkin',
      );

  @override
  List<Object?> get props => [
    sessionId,
    ruleId,
    ruleName,
    kind,
    multiplierBps,
    surchargeAmount,
    hourlyBase,
    hourlyLocked,
    occupancyPct,
    lockedAt,
    source,
  ];
}
