import 'package:equatable/equatable.dart';

/// Rounding helpers shared by the pricing entities (HH:MM <-> minutes).
int? minutesFromWire(Object? raw) {
  if (raw is! String || !raw.contains(':')) {
    return null;
  }
  final parts = raw.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return hour * 60 + minute;
}

String wireFromMinutes(int? minutes) {
  if (minutes == null) {
    return '';
  }
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// One dynamic-pricing rule (admin view).
class PricingRule extends Equatable {
  const PricingRule({
    required this.id,
    required this.name,
    required this.priority,
    required this.multiplierBps,
    this.active = true,
    this.group,
    this.minOccupancyPct,
    this.maxOccupancyPct,
    this.weekdays,
    this.fromMinute,
    this.toMinute,
    this.surchargeAmount = 0,
  });

  final int id;
  final String name;
  final bool active;
  final int priority;

  /// `car`, `moto`, `heavy` or null (every group).
  final String? group;
  final int? minOccupancyPct;
  final int? maxOccupancyPct;

  /// Bitmask over ISO weekdays (Mon = 1 ... Sun = 64); null = every day.
  final int? weekdays;
  final int? fromMinute;
  final int? toMinute;
  final int multiplierBps;
  final int surchargeAmount;

  bool get hasMultiplier => multiplierBps != 10000;
  bool get hasSurcharge => surchargeAmount > 0;
  bool get crossesMidnight =>
      fromMinute != null && toMinute != null && fromMinute! > toMinute!;

  Set<int> get weekdaySet => {
    for (var day = 1; day <= 7; day++)
      if (weekdays != null && (weekdays! & (1 << (day - 1))) != 0) day,
  };

  factory PricingRule.fromJson(Map<String, dynamic> json) => PricingRule(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    priority: (json['priority'] as num?)?.toInt() ?? 100,
    group: json['group'] as String?,
    minOccupancyPct: (json['min_occupancy_pct'] as num?)?.toInt(),
    maxOccupancyPct: (json['max_occupancy_pct'] as num?)?.toInt(),
    weekdays: (json['weekdays'] as num?)?.toInt(),
    fromMinute: minutesFromWire(json['from_time']),
    toMinute: minutesFromWire(json['to_time']),
    multiplierBps: (json['multiplier_bps'] as num?)?.toInt() ?? 10000,
    surchargeAmount: (json['surcharge_amount'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    active,
    priority,
    group,
    minOccupancyPct,
    maxOccupancyPct,
    weekdays,
    fromMinute,
    toMinute,
    multiplierBps,
    surchargeAmount,
  ];
}

/// Editable fields; `toParams` produces the `save_pricing_rule` payload.
class PricingRuleDraft extends Equatable {
  const PricingRuleDraft({
    this.id,
    required this.name,
    this.priority = 100,
    this.group,
    this.minOccupancyPct,
    this.maxOccupancyPct,
    this.weekdays,
    this.fromMinute,
    this.toMinute,
    this.multiplierBps = 10000,
    this.surchargeAmount = 0,
    this.active = true,
  });

  final int? id;
  final String name;
  final int priority;
  final String? group;
  final int? minOccupancyPct;
  final int? maxOccupancyPct;
  final int? weekdays;
  final int? fromMinute;
  final int? toMinute;
  final int multiplierBps;
  final int surchargeAmount;
  final bool active;

  factory PricingRuleDraft.fromRule(PricingRule rule) => PricingRuleDraft(
    id: rule.id,
    name: rule.name,
    priority: rule.priority,
    group: rule.group,
    minOccupancyPct: rule.minOccupancyPct,
    maxOccupancyPct: rule.maxOccupancyPct,
    weekdays: rule.weekdays,
    fromMinute: rule.fromMinute,
    toMinute: rule.toMinute,
    multiplierBps: rule.multiplierBps,
    surchargeAmount: rule.surchargeAmount,
    active: rule.active,
  );

  Map<String, dynamic> toParams() => {
    'p_name': name,
    'p_priority': priority,
    'p_group': group,
    'p_min_occupancy': minOccupancyPct,
    'p_max_occupancy': maxOccupancyPct,
    'p_weekdays': weekdays,
    'p_from_time': fromMinute == null ? null : wireFromMinutes(fromMinute),
    'p_to_time': toMinute == null ? null : wireFromMinutes(toMinute),
    'p_multiplier_bps': multiplierBps,
    'p_surcharge_amount': surchargeAmount,
    'p_active': active,
    'p_id': id,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    priority,
    group,
    minOccupancyPct,
    maxOccupancyPct,
    weekdays,
    fromMinute,
    toMinute,
    multiplierBps,
    surchargeAmount,
    active,
  ];
}
