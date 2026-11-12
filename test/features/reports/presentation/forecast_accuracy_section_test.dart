import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/application/reports_cubit.dart';
import 'package:parking_management/features/reports/domain/entities/forecast_backtest.dart';
import 'package:parking_management/features/reports/presentation/widgets/forecast_accuracy_section.dart';

import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/reports/domain/entities/hourly_traffic.dart';
import 'package:parking_management/features/reports/domain/entities/occupancy_report.dart';
import 'package:parking_management/features/reports/domain/entities/period_comparison.dart';
import 'package:parking_management/features/reports/domain/entities/reservation_report.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/domain/entities/whatsapp_report.dart';
import 'package:parking_management/features/reports/domain/repositories/report_repository.dart';

import '../../../helpers/test_app.dart';

/// Only the backtest matters here; the rest answers empty.
class FakeReportRepository implements ReportRepository {
  ForecastBacktest backtestToReturn = ForecastBacktest.empty;
  bool failBacktest = false;

  @override
  Future<ForecastBacktest> getForecastBacktest({int weeks = 4}) async {
    if (failBacktest) {
      throw const NetworkFailure('offline');
    }
    return backtestToReturn;
  }

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  }) async => RevenueReport(
    startDate: startDate,
    endDate: endDate,
    total: 0,
    byDay: const [],
    byCategory: const [],
  );

  @override
  Future<OccupancyReport> getOccupancyReport() async =>
      const OccupancyReport(totalOpen: 0, byCategory: []);

  @override
  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => WhatsappReport.empty;

  @override
  Future<ReservationReport> getReservationReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async => ReservationReport.empty;

  @override
  Future<HourlyTraffic> getHourlyTraffic({
    required DateTime startDate,
    required DateTime endDate,
  }) async => HourlyTraffic.empty;

  @override
  Future<PeriodComparison> getPeriodComparison({int months = 6}) async =>
      PeriodComparison.empty;
}

ForecastBacktest _backtest() => ForecastBacktest.fromJson({
  'weeks': 4,
  'groups': [
    {
      'group': 'car',
      'points': 100,
      'mae': 0.54,
      'mae_prior_only': 3.0,
      'bias': -0.2,
      'by_lead': [
        {'lead_hours': 3, 'points': 20, 'mae': 0.54, 'mae_prior_only': 3.0},
      ],
    },
  ],
});

Future<ReportsCubit> _pump(
  WidgetTester tester,
  FakeReportRepository repository,
) async {
  final cubit = ReportsCubit(repository);
  addTearDown(cubit.close);
  final today = DateTime(2026, 11, 12);
  await tester.runAsync(
    () => cubit.loadReports(startDate: today, endDate: today),
  );
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(
          body: SingleChildScrollView(child: ForecastAccuracySection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Success: an empty section offers to compute the accuracy', (
    tester,
  ) async {
    await _pump(tester, FakeReportRepository());

    expect(find.text('Precisión del pronóstico'), findsOneWidget);
    expect(find.byKey(const Key('forecast-backtest-run')), findsOneWidget);
  });

  testWidgets('Success: shows the mean error and the improvement', (
    tester,
  ) async {
    final repository = FakeReportRepository()..backtestToReturn = _backtest();
    final cubit = await _pump(tester, repository);
    await cubit.loadBacktest();
    await tester.pumpAndSettle();

    expect(find.textContaining('Error medio: 0.54'), findsWidgets);
    expect(find.textContaining('82 % mejor con datos en vivo'), findsOneWidget);
  });

  testWidgets('Failure: a failed backtest offers a retry', (tester) async {
    final repository = FakeReportRepository()..failBacktest = true;
    final cubit = await _pump(tester, repository);
    await cubit.loadBacktest();
    await tester.pumpAndSettle();

    expect(find.text('No se pudo calcular la precisión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
