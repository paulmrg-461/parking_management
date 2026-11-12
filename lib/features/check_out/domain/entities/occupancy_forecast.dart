import 'package:equatable/equatable.dart';

/// How the forecast ended: a usable projection or why it is not shown.
enum ForecastStatus { ok, disabled, insufficientHistory, noCapacity, unavailable }

ForecastStatus forecastStatusFrom(String? value) => switch (value) {
  'ok' => ForecastStatus.ok,
  'disabled' => ForecastStatus.disabled,
  'insufficient_history' => ForecastStatus.insufficientHistory,
  'no_capacity' => ForecastStatus.noCapacity,
  _ => ForecastStatus.unavailable,
};

/// How much history backs a group's cells.
enum ForecastConfidence { low, medium, high }

ForecastConfidence forecastConfidenceFrom(String? value) => switch (value) {
  'high' => ForecastConfidence.high,
  'medium' => ForecastConfidence.medium,
  _ => ForecastConfidence.low,
};

/// Bucket of one forecast hour relative to capacity.
enum ForecastLevel { free, busy, full }

ForecastLevel forecastLevelFrom(String? value) => switch (value) {
  'full' => ForecastLevel.full,
  'busy' => ForecastLevel.busy,
  _ => ForecastLevel.free,
};

class ForecastHour extends Equatable {
  const ForecastHour({
    required this.hour,
    required this.expected,
    required this.level,
  });

  /// Business-time hour (0..23).
  final int hour;

  /// Vehicles expected, already clamped to the capacity.
  final int expected;
  final ForecastLevel level;

  @override
  List<Object?> get props => [hour, expected, level];
}

class ForecastGroup extends Equatable {
  const ForecastGroup({
    required this.group,
    required this.capacity,
    required this.current,
    required this.confidence,
    required this.samples,
    required this.fullNow,
    required this.hours,
    this.fullAt,
  });

  /// `car` or `moto`.
  final String group;
  final int capacity;
  final int current;
  final ForecastConfidence confidence;
  final int samples;
  final bool fullNow;

  /// `HH:mm` business time, `null` when the group does not fill in the horizon.
  final String? fullAt;
  final List<ForecastHour> hours;

  /// The highest expected occupancy of the horizon.
  int get peakExpected =>
      hours.isEmpty ? 0 : hours.map((hour) => hour.expected).reduce((a, b) => a > b ? a : b);

  factory ForecastGroup.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'];
    return ForecastGroup(
      group: json['group'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      current: (json['current'] as num?)?.toInt() ?? 0,
      confidence: forecastConfidenceFrom(json['confidence'] as String?),
      samples: (json['samples'] as num?)?.toInt() ?? 0,
      fullNow: json['full_now'] == true,
      fullAt: json['full_at'] as String?,
      hours: rawHours is! List
          ? const []
          : [
              for (final item in rawHours)
                if (item is Map)
                  ForecastHour(
                    hour: (item['hour'] as num?)?.toInt() ?? 0,
                    expected: (item['expected'] as num?)?.toInt() ?? 0,
                    level: forecastLevelFrom(item['level'] as String?),
                  ),
            ],
    );
  }

  @override
  List<Object?> get props => [
    group,
    capacity,
    current,
    confidence,
    samples,
    fullNow,
    fullAt,
    hours,
  ];
}

/// "Will it be full at 6 pm?" for one lot: the profile blended with today.
class OccupancyForecast extends Equatable {
  const OccupancyForecast({
    required this.status,
    this.groups = const [],
    this.timezone = '',
    this.generatedAt,
  });

  final ForecastStatus status;
  final List<ForecastGroup> groups;
  final String timezone;
  final DateTime? generatedAt;

  static const unavailable = OccupancyForecast(
    status: ForecastStatus.unavailable,
  );

  bool get hasForecast => status == ForecastStatus.ok && groups.isNotEmpty;

  ForecastGroup? groupOf(String name) =>
      groups.where((group) => group.group == name).firstOrNull;

  /// The group that fills first: one that is already full wins, then the
  /// earliest `fullAt`.
  ForecastGroup? get firstToFill {
    if (!hasForecast) {
      return null;
    }
    ForecastGroup? winner;
    for (final group in groups) {
      if (group.fullNow) {
        return group;
      }
      final time = group.fullAt;
      if (time == null) {
        continue;
      }
      if (winner == null || time.compareTo(winner.fullAt ?? '') < 0) {
        winner = group;
      }
    }
    return winner;
  }

  factory OccupancyForecast.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'];
    if (rawGroups is! List) {
      return OccupancyForecast(
        status: forecastStatusFrom(json['status'] as String?),
        timezone: json['timezone'] as String? ?? '',
        generatedAt: _date(json['generated_at']),
      );
    }
    return OccupancyForecast(
      status: forecastStatusFrom(json['status'] as String?),
      timezone: json['timezone'] as String? ?? '',
      generatedAt: _date(json['generated_at']),
      groups: [
        for (final item in rawGroups)
          if (item is Map) ForecastGroup.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  @override
  List<Object?> get props => [status, groups, timezone, generatedAt];
}

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
