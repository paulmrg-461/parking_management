import 'package:equatable/equatable.dart';

import 'cash_anomaly.dart';

/// Per-lot thresholds (`anomaly_settings`); admin-only on the server.
class AnomalySettings extends Equatable {
  const AnomalySettings({
    this.enabled = true,
    this.disabledRules = const {},
    this.windowDays = 14,
    this.shortageMinAmount = 5000,
    this.shortageMinShifts = 3,
    this.lostTicketMinClosed = 10,
    this.lostTicketMinRatePct = 10,
    this.lostTicketFactorPct = 200,
    this.adjustmentMinAmount = 1000,
    this.shortStayMinutes = 30,
    this.discountMinCount = 3,
    this.discountSharePct = 10,
    this.shiftOpenHours = 16,
    this.sessionOpenDays = 7,
  });

  final bool enabled;
  final Set<AnomalyRule> disabledRules;
  final int windowDays;
  final int shortageMinAmount;
  final int shortageMinShifts;
  final int lostTicketMinClosed;
  final int lostTicketMinRatePct;
  final int lostTicketFactorPct;
  final int adjustmentMinAmount;
  final int shortStayMinutes;
  final int discountMinCount;
  final int discountSharePct;
  final int shiftOpenHours;
  final int sessionOpenDays;

  static const defaults = AnomalySettings();

  /// Only the keys `set_anomaly_settings` accepts.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'disabled_rules': [for (final rule in disabledRules) rule.wire],
    'window_days': windowDays,
    'shortage_min_amount': shortageMinAmount,
    'shortage_min_shifts': shortageMinShifts,
    'lost_ticket_min_closed': lostTicketMinClosed,
    'lost_ticket_min_rate_pct': lostTicketMinRatePct,
    'lost_ticket_factor_pct': lostTicketFactorPct,
    'adjustment_min_amount': adjustmentMinAmount,
    'short_stay_minutes': shortStayMinutes,
    'discount_min_count': discountMinCount,
    'discount_share_pct': discountSharePct,
    'shift_open_hours': shiftOpenHours,
    'session_open_days': sessionOpenDays,
  };

  factory AnomalySettings.fromJson(Map<String, dynamic> json) {
    int value(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    final rawRules = json['disabled_rules'];
    return AnomalySettings(
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : AnomalySettings.defaults.enabled,
      disabledRules: rawRules is! List
          ? const {}
          : {
              for (final item in rawRules)
                if (AnomalyRule.tryParse(item.toString()) case final rule?)
                  rule,
            },
      windowDays: value('window_days', 14),
      shortageMinAmount: value('shortage_min_amount', 5000),
      shortageMinShifts: value('shortage_min_shifts', 3),
      lostTicketMinClosed: value('lost_ticket_min_closed', 10),
      lostTicketMinRatePct: value('lost_ticket_min_rate_pct', 10),
      lostTicketFactorPct: value('lost_ticket_factor_pct', 200),
      adjustmentMinAmount: value('adjustment_min_amount', 1000),
      shortStayMinutes: value('short_stay_minutes', 30),
      discountMinCount: value('discount_min_count', 3),
      discountSharePct: value('discount_share_pct', 10),
      shiftOpenHours: value('shift_open_hours', 16),
      sessionOpenDays: value('session_open_days', 7),
    );
  }

  AnomalySettings copyWith({
    bool? enabled,
    Set<AnomalyRule>? disabledRules,
    int? windowDays,
    int? shortageMinAmount,
    int? shortageMinShifts,
    int? lostTicketMinClosed,
    int? lostTicketMinRatePct,
    int? lostTicketFactorPct,
    int? adjustmentMinAmount,
    int? shortStayMinutes,
    int? discountMinCount,
    int? discountSharePct,
    int? shiftOpenHours,
    int? sessionOpenDays,
  }) => AnomalySettings(
    enabled: enabled ?? this.enabled,
    disabledRules: disabledRules ?? this.disabledRules,
    windowDays: windowDays ?? this.windowDays,
    shortageMinAmount: shortageMinAmount ?? this.shortageMinAmount,
    shortageMinShifts: shortageMinShifts ?? this.shortageMinShifts,
    lostTicketMinClosed: lostTicketMinClosed ?? this.lostTicketMinClosed,
    lostTicketMinRatePct: lostTicketMinRatePct ?? this.lostTicketMinRatePct,
    lostTicketFactorPct: lostTicketFactorPct ?? this.lostTicketFactorPct,
    adjustmentMinAmount: adjustmentMinAmount ?? this.adjustmentMinAmount,
    shortStayMinutes: shortStayMinutes ?? this.shortStayMinutes,
    discountMinCount: discountMinCount ?? this.discountMinCount,
    discountSharePct: discountSharePct ?? this.discountSharePct,
    shiftOpenHours: shiftOpenHours ?? this.shiftOpenHours,
    sessionOpenDays: sessionOpenDays ?? this.sessionOpenDays,
  );

  @override
  List<Object?> get props => [
    enabled,
    disabledRules,
    windowDays,
    shortageMinAmount,
    shortageMinShifts,
    lostTicketMinClosed,
    lostTicketMinRatePct,
    lostTicketFactorPct,
    adjustmentMinAmount,
    shortStayMinutes,
    discountMinCount,
    discountSharePct,
    shiftOpenHours,
    sessionOpenDays,
  ];
}
