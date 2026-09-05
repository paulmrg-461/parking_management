import '../../../core/error/failure.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import '../domain/repositories/report_repository.dart';
import 'report_remote_data_source.dart';

/// Reports are remote-only (no offline local cache) and read-only, same
/// remote-only convention as check-out.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._auth, this._remote);

  final AuthRepository _auth;
  final ReportRemoteDataSource _remote;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _remote.getRevenueReport(
      await _currentToken(),
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<OccupancyReport> getOccupancyReport() async {
    return _remote.getOccupancyReport(await _currentToken());
  }

  Future<String> _currentToken() async {
    final session = await _auth.restoreSession();
    if (session == null) {
      throw const AuthenticationFailure('Not authenticated');
    }
    return session.token;
  }
}
