import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import '../domain/repositories/report_repository.dart';
import 'report_remote_data_source.dart';

/// Reports are remote-only (no offline local cache) and read-only, same
/// remote-only convention as check-out.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._remote);

  final ReportRemoteDataSource _remote;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _remote.getRevenueReport(startDate: startDate, endDate: endDate);
  }

  @override
  Future<OccupancyReport> getOccupancyReport() async {
    return _remote.getOccupancyReport();
  }
}
