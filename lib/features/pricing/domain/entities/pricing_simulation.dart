import 'package:equatable/equatable.dart';

class RuleImpact extends Equatable {
  const RuleImpact({
    required this.ruleId,
    required this.name,
    this.sessions = 0,
    this.delta = 0,
  });

  final int ruleId;
  final String name;
  final int sessions;
  final int delta;

  factory RuleImpact.fromJson(Map<String, dynamic> json) => RuleImpact(
    ruleId: (json['rule_id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    delta: (json['delta'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [ruleId, name, sessions, delta];
}

class HourImpact extends Equatable {
  const HourImpact({required this.hour, this.sessions = 0, this.delta = 0});

  final int hour;
  final int sessions;
  final int delta;

  factory HourImpact.fromJson(Map<String, dynamic> json) => HourImpact(
    hour: (json['hour'] as num?)?.toInt() ?? 0,
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    delta: (json['delta'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [hour, sessions, delta];
}

/// Read-only replay of the rules over the last N days.
class PricingSimulation extends Equatable {
  const PricingSimulation({
    this.days = 30,
    this.sessionsConsidered = 0,
    this.sessionsAffected = 0,
    this.baseTotal = 0,
    this.simulatedTotal = 0,
    this.delta = 0,
    this.deltaPctBps,
    this.atFloor = 0,
    this.atCeiling = 0,
    this.byRule = const [],
    this.byHour = const [],
  });

  final int days;
  final int sessionsConsidered;
  final int sessionsAffected;
  final int baseTotal;
  final int simulatedTotal;
  final int delta;
  final int? deltaPctBps;
  final int atFloor;
  final int atCeiling;
  final List<RuleImpact> byRule;
  final List<HourImpact> byHour;

  bool get isEmpty => sessionsConsidered == 0;

  factory PricingSimulation.fromJson(Map<String, dynamic> json) =>
      PricingSimulation(
        days: (json['days'] as num?)?.toInt() ?? 30,
        sessionsConsidered:
            (json['sessions_considered'] as num?)?.toInt() ?? 0,
        sessionsAffected: (json['sessions_affected'] as num?)?.toInt() ?? 0,
        baseTotal: (json['base_total'] as num?)?.toInt() ?? 0,
        simulatedTotal: (json['simulated_total'] as num?)?.toInt() ?? 0,
        delta: (json['delta'] as num?)?.toInt() ?? 0,
        deltaPctBps: (json['delta_pct_bps'] as num?)?.toInt(),
        atFloor: (json['at_floor'] as num?)?.toInt() ?? 0,
        atCeiling: (json['at_ceiling'] as num?)?.toInt() ?? 0,
        byRule: [
          for (final item in (json['by_rule'] as List? ?? const []))
            if (item is Map)
              RuleImpact.fromJson(Map<String, dynamic>.from(item)),
        ],
        byHour: [
          for (final item in (json['by_hour'] as List? ?? const []))
            if (item is Map)
              HourImpact.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  @override
  List<Object?> get props => [
    days,
    sessionsConsidered,
    sessionsAffected,
    baseTotal,
    simulatedTotal,
    delta,
    deltaPctBps,
    atFloor,
    atCeiling,
    byRule,
    byHour,
  ];
}
