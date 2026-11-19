import 'package:equatable/equatable.dart';

import '../../../check_out/domain/entities/capacity_snapshot.dart';
import '../../../check_out/domain/entities/dashboard_trend.dart';
import '../../../check_out/domain/entities/occupancy_snapshot.dart';
import '../../../check_out/domain/entities/today_summary.dart';

/// Last dashboard KPIs cached on the device, so an operator with no network
/// still sees the site state (clearly marked as stale) instead of an empty
/// home. The `version` field lets a future shape change ignore old entries.
class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.occupancy,
    required this.today,
    required this.trend,
    required this.capacity,
    required this.cachedAt,
  });

  static const schemaVersion = 1;

  final OccupancySnapshot occupancy;
  final TodaySummary today;
  final DashboardTrend trend;
  final CapacitySnapshot capacity;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'cached_at': cachedAt.toIso8601String(),
    'occupancy': occupancy.toJson(),
    'today': today.toJson(),
    'trend': trend.toJson(),
    'capacity': capacity.toJson(),
  };

  /// Returns `null` for another schema version or a malformed payload.
  static DashboardSnapshot? tryParse(Map<String, dynamic> json) {
    if (json['version'] != schemaVersion) {
      return null;
    }
    try {
      final rawDate = json['cached_at'];
      final cachedAt = rawDate is String
          ? DateTime.tryParse(rawDate)?.toLocal()
          : null;
      return DashboardSnapshot(
        occupancy: OccupancySnapshot.fromJson(
          Map<String, dynamic>.from(json['occupancy'] as Map),
        ),
        today: TodaySummary.fromJson(
          Map<String, dynamic>.from(json['today'] as Map),
        ),
        trend: DashboardTrend.fromJson(
          Map<String, dynamic>.from(json['trend'] as Map),
        ),
        capacity: CapacitySnapshot.fromJson(
          Map<String, dynamic>.from(json['capacity'] as Map),
        ),
        cachedAt: cachedAt ?? DateTime(1970),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [occupancy, today, trend, capacity, cachedAt];
}
