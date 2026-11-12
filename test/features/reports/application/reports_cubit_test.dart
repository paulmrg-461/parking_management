import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/hourly_traffic.dart';
import 'package:parking_management/features/reports/domain/entities/forecast_backtest.dart';
import 'package:parking_management/features/reports/domain/entities/period_comparison.dart';
import 'package:parking_management/features/reports/domain/entities/reservation_report.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/entities/whatsapp_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';

class _FakeReportRepository implements ReportRepository {
  ForecastBacktest backtestToReturn = ForecastBacktest.empty;
  bool failBacktest = false;
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
  ReservationReport reservations = ReservationReport.empty;
  PeriodComparison comparisonToReturn = PeriodComparison.empty;
  Failure? failComparison;
  int? comparisonMonthsRequested;
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

  HourlyTraffic? hourlyToReturn;
  bool failHourly = false;

  @override
  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => WhatsappReport.empty;

  @override
  Future<ForecastBacktest> getForecastBacktest({int weeks = 4}) async {
    if (failBacktest) {
      throw const NetworkFailure('offline');
    }
    return backtestToReturn;
  }

  Future<PeriodComparison> getPeriodComparison({int months = 6}) async {
    comparisonMonthsRequested = months;
    final error = failComparison;
    if (error != null) {
      throw error;
    }
    return comparisonToReturn;
  }

  @override
  Future<ReservationReport> getReservationReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => reservations;

  @override
  Future<HourlyTraffic> getHourlyTraffic({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (failHourly) {
      throw const NetworkFailure('offline');
    }
    return hourlyToReturn ?? HourlyTraffic.empty;
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

  PeriodComparison comparisonFixture({int months = 6}) =>
      PeriodComparison.fromJson({
        'months': months,
        'buckets': [
          {
            'month': '2026-10',
            'is_partial': false,
            'current': {'revenue': 100, 'days': 31, 'covered': true},
            'previous_month': {'revenue': 90, 'days': 31, 'covered': true},
            'previous_year': {'revenue': 0, 'days': 31, 'covered': false},
          },
        ],
      });

  test('Success: comparison lands in ReportsLoaded', () async {
    final repository = _FakeReportRepository(
      revenueToReturn: revenue,
      occupancyToReturn: occupancy,
    )..comparisonToReturn = comparisonFixture();
    final cubit = ReportsCubit(repository);

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      comparisonMonths: 12,
    );

    final state = cubit.state;
    expect(state, isA<ReportsLoaded>());
    expect(
      (state as ReportsLoaded).comparison.buckets.single.monthKey,
      '2026-10',
    );
    expect(state.comparisonMonths, 12);
    expect(repository.comparisonMonthsRequested, 12);
  });

  test('Failure: a broken comparison never fails the page', () async {
    final repository = _FakeReportRepository(
      revenueToReturn: revenue,
      occupancyToReturn: occupancy,
    )..failComparison = const NetworkFailure('offline');
    final cubit = ReportsCubit(repository);

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final state = cubit.state;
    expect(state, isA<ReportsLoaded>());
    expect((state as ReportsLoaded).comparisonFailed, isTrue);
    expect(state.comparison, PeriodComparison.empty);
    expect(state.revenue.total, 100000);
  });

  test(
    'Success: loadComparison switches months without ReportsLoading',
    () async {
      final repository = _FakeReportRepository(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      )..comparisonToReturn = comparisonFixture();
      final cubit = ReportsCubit(repository);
      await cubit.loadReports(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      final seen = <ReportsState>[];
      final subscription = cubit.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      await cubit.loadComparison(months: 12);

      expect(seen.any((s) => s is ReportsLoading), isFalse);
      expect((cubit.state as ReportsLoaded).comparisonMonths, 12);
      expect((cubit.state as ReportsLoaded).comparisonLoading, isFalse);
    },
  );

  test(
    'Failure: loadComparison failure keeps the report and flags it',
    () async {
      final repository = _FakeReportRepository(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      )..comparisonToReturn = comparisonFixture();
      final cubit = ReportsCubit(repository);
      await cubit.loadReports(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      repository.failComparison = const NetworkFailure('offline');

      await cubit.loadComparison(months: 12);

      final state = cubit.state as ReportsLoaded;
      expect(state.comparisonFailed, isTrue);
      expect(state.comparison, PeriodComparison.empty);
      expect(state.revenue.total, 100000);
    },
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

  test('Failure: loadReports emits ReportsFailure when the repository throws NetworkFailure', () async {
    final cubit = ReportsCubit(
      _FakeReportRepository(error: const NetworkFailure('offline')),
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    expect(cubit.state, const ReportsFailure('offline'));
  });

  test('Success: hourly traffic lands in the loaded state', () async {
    final cubit = ReportsCubit(
      _FakeReportRepository(
          revenueToReturn: revenue,
          occupancyToReturn: occupancy,
        )
        ..hourlyToReturn = const HourlyTraffic(
          timezone: 'America/Bogota',
          hours: [
            HourlyTrafficPoint(hour: 8, entries: 4, exits: 2),
            HourlyTrafficPoint(hour: 9, entries: 1, exits: 3),
          ],
        ),
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final state = cubit.state as ReportsLoaded;
    expect(state.hourly.timezone, 'America/Bogota');
    expect(state.hourly.peak!.hour, 8);
    expect(state.hourly.peakEntries, 4);
  });

  test('Failure: a broken hourly report never fails the page', () async {
    final cubit = ReportsCubit(
      _FakeReportRepository(
        revenueToReturn: revenue,
        occupancyToReturn: occupancy,
      )..failHourly = true,
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    final state = cubit.state as ReportsLoaded;
    expect(state.hourly, HourlyTraffic.empty);
    expect(state.revenue.total, 100000);
  });

  test('Security: a mapped 403 (non-admin) AuthenticationFailure becomes ReportsFailure, not a crash', () async {
    final cubit = ReportsCubit(
      _FakeReportRepository(error: const AuthenticationFailure('Forbidden')),
    );

    await cubit.loadReports(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );

    expect(cubit.state, const ReportsFailure('Forbidden'));
  });

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

  test(
    'Security: a failing previous period keeps the current report',
    () async {
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
    },
  );
}
