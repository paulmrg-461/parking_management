import '../entities/hourly_traffic.dart';
import '../entities/occupancy_report.dart';
import '../entities/forecast_backtest.dart';
import '../entities/period_comparison.dart';
import '../entities/reservation_report.dart';
import '../entities/revenue_report.dart';
import '../entities/whatsapp_report.dart';

abstract class ReportRepository {
  /// [allLots] asks for the consolidated admin report (every site plus a
  /// per-lot breakdown); the default is the active lot only.
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  });

  Future<OccupancyReport> getOccupancyReport();

  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Trailing [months] calendar months of the active lot, each with the month
  /// before and the same month last year (`rpc/report_period_comparison`).
  Future<PeriodComparison> getPeriodComparison({int months = 6});

  /// Forecast accuracy replayed over the last [weeks] weeks.
  Future<ForecastBacktest> getForecastBacktest({int weeks = 4});

  /// Holds created in the range, by origin and outcome.
  Future<ReservationReport> getReservationReport({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Entries/exits per hour of the business day for the range.
  Future<HourlyTraffic> getHourlyTraffic({
    required DateTime startDate,
    required DateTime endDate,
  });
}
