import 'package:equatable/equatable.dart';

/// Error of the occupancy forecast replayed over past weeks
/// (`rpc/occupancy_forecast_backtest`), next to the profile-only error.
class ForecastBacktest extends Equatable {
  const ForecastBacktest({
    this.weeks = 0,
    this.historyWeeks = 0,
    this.decayPct = 0,
    this.issueHours = const [],
    this.groups = const [],
  });

  final int weeks;
  final int historyWeeks;
  final int decayPct;
  final List<int> issueHours;
  final List<BacktestGroup> groups;

  static const empty = ForecastBacktest();

  bool get hasData => groups.any((group) => group.points > 0);

  factory ForecastBacktest.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    final groups = json['groups'];
    final hours = json['issue_hours'];
    return ForecastBacktest(
      weeks: value(json['weeks']),
      historyWeeks: value(json['history_weeks']),
      decayPct: value(json['decay_pct']),
      issueHours: hours is! List ? const [] : [for (final h in hours) value(h)],
      groups: groups is! List
          ? const []
          : [
              for (final item in groups)
                if (item is Map)
                  BacktestGroup.fromJson(Map<String, dynamic>.from(item)),
            ],
    );
  }

  @override
  List<Object?> get props => [weeks, historyWeeks, decayPct, issueHours, groups];
}

class BacktestGroup extends Equatable {
  const BacktestGroup({
    required this.group,
    required this.points,
    required this.bias,
    this.mae,
    this.maePriorOnly,
    this.byLead = const [],
  });

  final String group;
  final int points;

  /// Mean absolute error with the live blend (`null` without points).
  final double? mae;
  final double? maePriorOnly;

  /// Mean signed error: positive means the forecast overshoots.
  final double bias;
  final List<BacktestLead> byLead;

  bool get isBetter => mae != null && maePriorOnly != null && mae! < maePriorOnly!;

  /// How much better than the profile alone, in percent (`null` when it is not).
  int? get improvement {
    final prior = maePriorOnly;
    if (mae == null || prior == null || prior == 0) {
      return null;
    }
    return ((prior - mae!) * 100 / prior).round();
  }

  factory BacktestGroup.fromJson(Map<String, dynamic> json) {
    double? decimal(Object? raw) => raw is num ? raw.toDouble() : null;
    final leads = json['by_lead'];
    return BacktestGroup(
      group: json['group'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      mae: decimal(json['mae']),
      maePriorOnly: decimal(json['mae_prior_only']),
      bias: decimal(json['bias']) ?? 0,
      byLead: leads is! List
          ? const []
          : [
              for (final item in leads)
                if (item is Map)
                  BacktestLead.fromJson(Map<String, dynamic>.from(item)),
            ],
    );
  }

  @override
  List<Object?> get props => [group, points, mae, maePriorOnly, bias, byLead];
}

class BacktestLead extends Equatable {
  const BacktestLead({
    required this.leadHours,
    required this.points,
    this.mae,
    this.maePriorOnly,
  });

  final int leadHours;
  final int points;
  final double? mae;
  final double? maePriorOnly;

  factory BacktestLead.fromJson(Map<String, dynamic> json) => BacktestLead(
    leadHours: (json['lead_hours'] as num?)?.toInt() ?? 0,
    points: (json['points'] as num?)?.toInt() ?? 0,
    mae: json['mae'] is num ? (json['mae'] as num).toDouble() : null,
    maePriorOnly: json['mae_prior_only'] is num
        ? (json['mae_prior_only'] as num).toDouble()
        : null,
  );

  @override
  List<Object?> get props => [leadHours, points, mae, maePriorOnly];
}
