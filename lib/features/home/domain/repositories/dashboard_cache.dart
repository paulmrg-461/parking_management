import '../entities/dashboard_snapshot.dart';

/// Device-local cache for the home KPIs (one entry per site).
abstract class DashboardCache {
  Future<DashboardSnapshot?> read();

  Future<void> write(DashboardSnapshot snapshot);
}
