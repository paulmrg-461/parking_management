import 'package:equatable/equatable.dart';

import 'pricing_simulation.dart';

/// Real impact of the locks in a business-date window.
class PricingImpactReport extends Equatable {
  const PricingImpactReport({
    this.lockedSessions = 0,
    this.surchargedSessions = 0,
    this.discountedSessions = 0,
    this.extraRevenue = 0,
    this.discountGiven = 0,
    this.netDelta = 0,
    this.byRule = const [],
  });

  final int lockedSessions;
  final int surchargedSessions;
  final int discountedSessions;
  final int extraRevenue;
  final int discountGiven;
  final int netDelta;
  final List<RuleImpact> byRule;

  bool get hasData => lockedSessions > 0;

  factory PricingImpactReport.fromJson(Map<String, dynamic> json) =>
      PricingImpactReport(
        lockedSessions: (json['locked_sessions'] as num?)?.toInt() ?? 0,
        surchargedSessions: (json['surcharged_sessions'] as num?)?.toInt() ?? 0,
        discountedSessions: (json['discounted_sessions'] as num?)?.toInt() ?? 0,
        extraRevenue: (json['extra_revenue'] as num?)?.toInt() ?? 0,
        discountGiven: (json['discount_given'] as num?)?.toInt() ?? 0,
        netDelta: (json['net_delta'] as num?)?.toInt() ?? 0,
        byRule: [
          for (final item in (json['by_rule'] as List? ?? const []))
            if (item is Map)
              RuleImpact.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  @override
  List<Object?> get props => [
    lockedSessions,
    surchargedSessions,
    discountedSessions,
    extraRevenue,
    discountGiven,
    netDelta,
    byRule,
  ];
}
