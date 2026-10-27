import '../entities/occupancy_report.dart';
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
}
