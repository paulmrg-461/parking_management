import 'package:equatable/equatable.dart';

/// One calendar day of the home trend (`rpc/dashboard_trend`).
class TrendDay extends Equatable {
  const TrendDay({
    required this.date,
    this.revenue = 0,
    this.entries = 0,
    this.exits = 0,
  });

  /// Business-day date (timezone of the site), at local midnight.
  final DateTime date;
  final int revenue;
  final int entries;
  final int exits;

  factory TrendDay.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    final rawDate = json['date'];
    return TrendDay(
      date: rawDate is String && rawDate.isNotEmpty
          ? DateTime.tryParse(rawDate) ?? DateTime(1970)
          : DateTime(1970),
      revenue: value(json['revenue']),
      entries: value(json['entries']),
      exits: value(json['exits']),
    );
  }

  bool get hasMovement => revenue != 0 || entries != 0 || exits != 0;

  /// `YYYY-MM-DD` in the site's business day (matches the RPC payload).
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'date': dateKey,
    'revenue': revenue,
    'entries': entries,
    'exits': exits,
  };

  @override
  List<Object?> get props => [date, revenue, entries, exits];
}

/// Daily activity series for the active site, oldest day first.
class DashboardTrend extends Equatable {
  const DashboardTrend({this.days = const []});

  final List<TrendDay> days;

  static const empty = DashboardTrend();

  factory DashboardTrend.fromJson(Map<String, dynamic> json) {
    final raw = json['days'];
    if (raw is! List) {
      return DashboardTrend.empty;
    }
    final days = [
      for (final item in raw)
        if (item is Map) TrendDay.fromJson(Map<String, dynamic>.from(item)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return DashboardTrend(days: days);
  }

  bool get isEmpty => days.isEmpty;

  bool get hasMovement => days.any((day) => day.hasMovement);

  /// The last [length] days, or fewer when the series is short.
  List<TrendDay> latest(int length) => window(length);

  /// A [length]-day slice ending [skip] days before the newest one.
  /// Returns an empty list when the series does not cover it.
  List<TrendDay> window(int length, {int skip = 0}) {
    final end = days.length - skip;
    if (length <= 0 || end <= 0) {
      return const [];
    }
    final start = (end - length).clamp(0, end);
    return days.sublist(start, end);
  }

  /// Revenue of a slice, so the card can compare two consecutive weeks.
  int revenueOf(List<TrendDay> slice) =>
      slice.fold<int>(0, (sum, day) => sum + day.revenue);

  int get totalRevenue => days.fold<int>(0, (sum, day) => sum + day.revenue);

  int get totalEntries => days.fold<int>(0, (sum, day) => sum + day.entries);

  int get totalExits => days.fold<int>(0, (sum, day) => sum + day.exits);

  /// Highest daily revenue, used to scale the bars (`0` when quiet).
  int get peakRevenue =>
      days.fold<int>(0, (peak, day) => day.revenue > peak ? day.revenue : peak);

  @override
  List<Object?> get props => [days];

  Map<String, dynamic> toJson() => {
    'days': [for (final day in days) day.toJson()],
  };
}
