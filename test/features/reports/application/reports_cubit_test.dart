import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/entities/whatsapp_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository({
    this.revenueToReturn,
    this.previousRevenue,
    this.occupancyToReturn,
    this.error,
  });

  final RevenueReport? revenueToReturn;
  final RevenueReport? previousRevenue;
  final OccupancyReport? occupancyToReturn;
  final Failure? error;
  bool failPrevious = false;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    // The cubit asks for the previous window after the current one; its
    // endDate falls before the current report's start.
    if (endDate.isBefore(revenueToReturn!.startDate)) {
      if (failPrevious) {
        throw const NetworkFailure('offline');
      }
      return previousRevenue ?? revenueToReturn!;
    }
    return revenueToReturn!;
  }

  @override
  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => WhatsappReport.empty;

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

      final state = cubit.state as ReportsLoaded;
      expect(state.revenue, revenue);
      expect(state.occupancy, occupancy);
      expect(state.previousTotal, revenue.total);
      expect(state.previousEnd, DateTime(2025, 12, 31));
      expect(state.previousStart, DateTime(2025, 12, 1));
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

  test('Success: the previous period drives the delta percentage', () async {
    final previous = RevenueReport(
      startDate: DateTime(2025, 12, 1),
      endDate: DateTime(2025, 12, 31),
      total: 80000,
      byDay: const [],
      byCategory: const [],
    );
    final cubit = ReportsCubit(
      _FakeReportRepository(
        revenueToReturn: revenue,
        previousRevenue: previous,
        occupancyToReturn: occupancy,
      ),
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final state = cubit.state as ReportsLoaded;
    expect(state.previousTotal, 80000);
    expect(state.deltaPercent, 25);
  });

  test('Security: a failing previous period keeps the current report', () async {
    final cubit = ReportsCubit(
      _FakeReportRepository(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      )..failPrevious = true,
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final state = cubit.state as ReportsLoaded;
    expect(state.previousTotal, isNull);
    expect(state.deltaPercent, isNull);
    expect(state.revenue.total, 100000);
  });
}
