import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository({
    this.revenueToReturn,
    this.occupancyToReturn,
    this.error,
  });

  final RevenueReport? revenueToReturn;
  final OccupancyReport? occupancyToReturn;
  final Failure? error;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return revenueToReturn!;
  }

  @override
  Future<OccupancyReport> getOccupancyReport() async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return occupancyToReturn!;
  }
}

void main() {
  final revenue = RevenueReport(
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 31),
    total: 100000,
    byDay: [DailyRevenue(date: DateTime(2026, 1, 1), amount: 100000)],
    byCategory: const [
      CategoryRevenue(categoryId: 1, categoryName: 'Car', amount: 100000),
    ],
  );
  const occupancy = OccupancyReport(
    totalOpen: 5,
    byCategory: [
      CategoryOccupancy(categoryId: 1, categoryName: 'Car', count: 5),
    ],
  );

  test(
    'Success: loadReports emits ReportsLoaded with both revenue and occupancy',
    () async {
      final cubit = ReportsCubit(
        _FakeReportRepository(
          revenueToReturn: revenue,
          occupancyToReturn: occupancy,
        ),
      );

      await cubit.loadReports(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(cubit.state, ReportsLoaded(revenue, occupancy));
    },
  );

  test(
    'Failure: loadReports emits ReportsFailure when the repository throws NetworkFailure',
    () async {
      final cubit = ReportsCubit(
        _FakeReportRepository(error: const NetworkFailure('offline')),
      );

      await cubit.loadReports(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(cubit.state, const ReportsFailure('offline'));
    },
  );

  test(
    'Security: a mapped 403 (non-admin) AuthenticationFailure becomes ReportsFailure, not a crash',
    () async {
      final cubit = ReportsCubit(
        _FakeReportRepository(error: const AuthenticationFailure('Forbidden')),
      );

      await cubit.loadReports(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(cubit.state, const ReportsFailure('Forbidden'));
    },
  );
}
