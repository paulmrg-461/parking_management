import 'package:parking_management/features/home/domain/entities/dashboard_snapshot.dart';
import 'package:parking_management/features/home/domain/repositories/dashboard_cache.dart';

/// In-memory [DashboardCache] for cubit/widget tests.
class FakeDashboardCache implements DashboardCache {
  DashboardSnapshot? snapshot;
  int reads = 0;
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<DashboardSnapshot?> read() async {
    reads++;
    if (failRead) {
      throw StateError('cache read failed');
    }
    return snapshot;
  }

  @override
  Future<void> write(DashboardSnapshot next) async {
    writes++;
    if (failWrite) {
      throw StateError('cache write failed');
    }
    snapshot = next;
  }
}
