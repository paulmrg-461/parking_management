import 'package:equatable/equatable.dart';

/// "Today" counters for the active site (`rpc/dashboard_today`).
class TodaySummary extends Equatable {
  const TodaySummary({
    this.revenue = 0,
    this.cashRevenue = 0,
    this.passRevenue = 0,
    this.entries = 0,
    this.exits = 0,
    this.openNow = 0,
  });

  final int revenue;
  final int cashRevenue;
  final int passRevenue;
  final int entries;
  final int exits;
  final int openNow;

  static const empty = TodaySummary();

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return TodaySummary(
      revenue: value(json['revenue']),
      cashRevenue: value(json['cash_revenue']),
      passRevenue: value(json['pass_revenue']),
      entries: value(json['entries']),
      exits: value(json['exits']),
      openNow: value(json['open_now']),
    );
  }

  @override
  List<Object?> get props => [
    revenue,
    cashRevenue,
    passRevenue,
    entries,
    exits,
    openNow,
  ];
}
