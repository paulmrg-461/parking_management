import '../entities/occupancy_report.dart';
import '../entities/revenue_report.dart';

abstract class ReportRepository {
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<OccupancyReport> getOccupancyReport();
}
