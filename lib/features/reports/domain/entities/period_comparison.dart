import 'package:equatable/equatable.dart';

/// Metric the comparison chart and the summary can show.
enum PeriodMetric {
  revenue,
  entries,
  exits,
  avgTicket,
  avgStay,
  passRevenue,
  reservations,
}

/// One measured window (`rpc/report_period_comparison`): the month itself, the
/// month before it or the same month last year.
class PeriodWindow extends Equatable {
  const PeriodWindow({
    required this.startDate,
    required this.endDate,
    this.days = 0,
    this.fullMonth = false,
    this.covered = false,
    this.revenue = 0,
    this.entries = 0,
    this.exits = 0,
    this.avgTicket = 0,
    this.avgStayMinutes = 0,
    this.passRevenue = 0,
    this.reservations = 0,
    this.reservationsUsed = 0,
  });

  /// Local midnight of the first business day counted.
  final DateTime startDate;

  /// Last business day counted (inclusive).
  final DateTime endDate;

  final int days;

  /// The window is a whole calendar month (comparable with another month).
  final bool fullMonth;

  /// The lot already had sessions on or before [startDate].
  final bool covered;

  /// Minor units.
  final int revenue;
  final int entries;
  final int exits;
  final int avgTicket;
  final int avgStayMinutes;
  final int passRevenue;
  final int reservations;
  final int reservationsUsed;

  int valueOf(PeriodMetric metric) => switch (metric) {
    PeriodMetric.revenue => revenue,
    PeriodMetric.entries => entries,
    PeriodMetric.exits => exits,
    PeriodMetric.avgTicket => avgTicket,
    PeriodMetric.avgStay => avgStayMinutes,
    PeriodMetric.passRevenue => passRevenue,
    PeriodMetric.reservations => reservations,
  };

  bool get hasMovement =>
      revenue != 0 ||
      entries != 0 ||
      exits != 0 ||
      passRevenue != 0 ||
      reservations != 0;

  factory PeriodWindow.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    DateTime day(Object? raw) =>
        DateTime.tryParse((raw as String?) ?? '') ?? DateTime(1970);
    return PeriodWindow(
      startDate: day(json['start_date']),
      endDate: day(json['end_date']),
      days: value(json['days']),
      fullMonth: json['full_month'] as bool? ?? false,
      covered: json['covered'] as bool? ?? false,
      revenue: value(json['revenue']),
      entries: value(json['entries']),
      exits: value(json['exits']),
      avgTicket: value(json['avg_ticket']),
      avgStayMinutes: value(json['avg_stay_minutes']),
      passRevenue: value(json['pass_revenue']),
      reservations: value(json['reservations']),
      reservationsUsed: value(json['reservations_used']),
    );
  }

  @override
  List<Object?> get props => [
    startDate,
    endDate,
    days,
    fullMonth,
    covered,
    revenue,
    entries,
    exits,
    avgTicket,
    avgStayMinutes,
    passRevenue,
    reservations,
    reservationsUsed,
  ];
}

/// One month of the comparison.
class PeriodBucket extends Equatable {
  const PeriodBucket({
    required this.month,
    required this.current,
    required this.previousMonth,
    required this.previousYear,
    this.isPartial = false,
  });

  /// First day of the month.
  final DateTime month;

  /// The month is still running: its windows compare elapsed days only.
  final bool isPartial;
  final PeriodWindow current;
  final PeriodWindow previousMonth;
  final PeriodWindow previousYear;

  /// `YYYY-MM`, the key the tests and the chart use.
  String get monthKey =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  int? deltaVsMonth(PeriodMetric metric) =>
      periodDelta(current, previousMonth, metric);

  int? deltaVsYear(PeriodMetric metric) =>
      periodDelta(current, previousYear, metric);

  factory PeriodBucket.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> window(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    final month = json['month'] as String? ?? '';
    return PeriodBucket(
      month: DateTime.tryParse('$month-01') ?? DateTime(1970),
      isPartial: json['is_partial'] as bool? ?? false,
      current: PeriodWindow.fromJson(window(json['current'])),
      previousMonth: PeriodWindow.fromJson(window(json['previous_month'])),
      previousYear: PeriodWindow.fromJson(window(json['previous_year'])),
    );
  }

  @override
  List<Object?> get props => [
    month,
    isPartial,
    current,
    previousMonth,
    previousYear,
  ];
}

/// Trailing months of the active lot with their two comparison windows.
class PeriodComparison extends Equatable {
  const PeriodComparison({
    this.buckets = const [],
    this.months = 0,
    this.timezone = '',
    this.asOf,
    this.firstActivityDate,
  });

  static const empty = PeriodComparison();

  /// Oldest first.
  final List<PeriodBucket> buckets;
  final int months;
  final String timezone;
  final DateTime? asOf;
  final DateTime? firstActivityDate;

  bool get isEmpty => buckets.isEmpty;

  bool get hasData => buckets.any((bucket) => bucket.current.hasMovement);

  PeriodBucket? get latest => buckets.isEmpty ? null : buckets.last;

  /// Highest value over the current and the same month last year, used to
  /// scale the bars (`0` when the period is quiet).
  int peakOf(PeriodMetric metric) {
    var peak = 0;
    for (final bucket in buckets) {
      for (final window in [bucket.current, bucket.previousYear]) {
        final value = window.valueOf(metric);
        if (value > peak) {
          peak = value;
        }
      }
    }
    return peak;
  }

  factory PeriodComparison.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'];
    if (rawBuckets is! List) {
      return PeriodComparison.empty;
    }
    final buckets = [
      for (final item in rawBuckets)
        if (item is Map) PeriodBucket.fromJson(Map<String, dynamic>.from(item)),
    ]..sort((a, b) => a.month.compareTo(b.month));
    DateTime? day(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
    return PeriodComparison(
      buckets: buckets,
      months: (json['months'] as num?)?.toInt() ?? 0,
      timezone: json['timezone'] as String? ?? '',
      asOf: day(json['as_of']),
      firstActivityDate: day(json['first_activity_date']),
    );
  }

  @override
  List<Object?> get props => [
    buckets,
    months,
    timezone,
    asOf,
    firstActivityDate,
  ];
}

/// Percent change of [metric] between [current] and [base], or null when the
/// base cannot support a comparison: the lot was not active yet, the base is
/// zero, or it covers a different number of days and is not a full month.
/// Mirrors the rule `TrendCard` applies on the home dashboard.
int? periodDelta(PeriodWindow current, PeriodWindow base, PeriodMetric metric) {
  final baseValue = base.valueOf(metric);
  final comparableLength = base.days == current.days || base.fullMonth;
  if (!base.covered || baseValue <= 0 || !comparableLength) {
    return null;
  }
  return ((current.valueOf(metric) - baseValue) * 100 / baseValue).round();
}
