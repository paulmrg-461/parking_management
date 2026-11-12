import 'package:equatable/equatable.dart';

/// Entries/exits for one hour of the business day (`rpc/report_hourly_traffic`).
class HourlyTrafficPoint extends Equatable {
  const HourlyTrafficPoint({
    required this.hour,
    this.entries = 0,
    this.exits = 0,
  });

  /// 0..23 in the site's business timezone.
  final int hour;
  final int entries;
  final int exits;

  int get total => entries + exits;

  /// `08:00`; locale-independent, used by the grid, CSV and PDF.
  String get timeLabel => '${hour.toString().padLeft(2, '0')}:00';

  factory HourlyTrafficPoint.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return HourlyTrafficPoint(
      hour: value(json['hour']).clamp(0, 23),
      entries: value(json['entries']),
      exits: value(json['exits']),
    );
  }

  @override
  List<Object?> get props => [hour, entries, exits];
}

/// Hourly activity for a report range, ordered 00:00 → 23:00.
class HourlyTraffic extends Equatable {
  const HourlyTraffic({this.hours = const [], this.timezone = ''});

  final List<HourlyTrafficPoint> hours;
  final String timezone;

  static const empty = HourlyTraffic();

  bool get hasData => hours.any((point) => point.total > 0);

  /// Highest entry count, used to scale the bars (`0` when quiet).
  int get peakEntries => hours.fold<int>(
    0,
    (peak, point) => point.entries > peak ? point.entries : peak,
  );

  /// Busiest entry hour; ties keep the earliest. `null` when nobody entered.
  HourlyTrafficPoint? get peak {
    HourlyTrafficPoint? best;
    for (final point in hours) {
      if (point.entries == 0) {
        continue;
      }
      if (best == null || point.entries > best.entries) {
        best = point;
      }
    }
    return best;
  }

  factory HourlyTraffic.fromJson(Map<String, dynamic> json) {
    final raw = json['hours'];
    if (raw is! List) {
      return HourlyTraffic.empty;
    }
    final points = [
      for (final item in raw)
        if (item is Map)
          HourlyTrafficPoint.fromJson(Map<String, dynamic>.from(item)),
    ]..sort((a, b) => a.hour.compareTo(b.hour));
    return HourlyTraffic(
      hours: points,
      timezone: json['timezone'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [hours, timezone];
}
