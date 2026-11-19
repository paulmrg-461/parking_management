import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/dashboard_trend.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/home/domain/entities/dashboard_snapshot.dart';

/// Cached dashboard fixture shared by the cache/cubit/widget tests.
DashboardSnapshot sampleDashboardSnapshot({DateTime? cachedAt}) =>
    DashboardSnapshot(
      occupancy: const OccupancySnapshot(
        totalOpen: 3,
        totalCapacity: 10,
        byCategory: [
          CategoryOccupancySnapshot(
            categoryId: 1,
            name: 'car',
            count: 3,
            capacity: 10,
            isFull: false,
          ),
        ],
      ),
      today: const TodaySummary(
        revenue: 25000,
        cashRevenue: 15000,
        passRevenue: 5000,
        entries: 4,
        exits: 2,
        openNow: 3,
      ),
      trend: DashboardTrend(
        days: [
          TrendDay(date: DateTime(2026, 11, 8), revenue: 8000, entries: 2),
          TrendDay(date: DateTime(2026, 11, 9), revenue: 12000, entries: 3),
        ],
      ),
      capacity: const CapacitySnapshot(
        carOpen: 3,
        carCapacity: 10,
        carTargetCapacity: 12,
        carReserved: 1,
        motoOpen: 1,
        motoCapacity: 4,
        keysOpen: 2,
        keyCapacity: 5,
        reservationsActive: 1,
        reservationsExpiring: 1,
      ),
      cachedAt: cachedAt ?? DateTime(2026, 11, 9, 14, 32),
    );
