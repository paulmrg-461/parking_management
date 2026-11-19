import 'package:equatable/equatable.dart';

/// The three guard rails and the lot switch.
class PricingSettings extends Equatable {
  const PricingSettings({
    this.enabled = false,
    this.floorBps = 10000,
    this.ceilingBps = 15000,
    this.roundTo = 1,
  });

  final bool enabled;
  final int floorBps;
  final int ceilingBps;
  final int roundTo;

  PricingSettings copyWith({
    bool? enabled,
    int? floorBps,
    int? ceilingBps,
    int? roundTo,
  }) => PricingSettings(
    enabled: enabled ?? this.enabled,
    floorBps: floorBps ?? this.floorBps,
    ceilingBps: ceilingBps ?? this.ceilingBps,
    roundTo: roundTo ?? this.roundTo,
  );

  factory PricingSettings.fromJson(Map<String, dynamic> json) =>
      PricingSettings(
        enabled: json['enabled'] as bool? ?? false,
        floorBps: (json['floor_bps'] as num?)?.toInt() ?? 10000,
        ceilingBps: (json['ceiling_bps'] as num?)?.toInt() ?? 15000,
        roundTo: (json['round_to'] as num?)?.toInt() ?? 1,
      );

  @override
  List<Object?> get props => [enabled, floorBps, ceilingBps, roundTo];
}
