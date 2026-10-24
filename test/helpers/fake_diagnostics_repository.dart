import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/diagnostics/domain/entities/client_error_report.dart';
import 'package:parking_management/features/diagnostics/domain/entities/diagnostics_snapshot.dart';
import 'package:parking_management/features/diagnostics/domain/repositories/diagnostics_repository.dart';

class FakeDiagnosticsRepository implements DiagnosticsRepository {
  FakeDiagnosticsRepository({
    DiagnosticsSnapshot? snapshot,
    List<ClientErrorReport> errors = const [],
  }) : snapshotValue = snapshot ?? sampleSnapshot(),
       errors = List.of(errors);

  DiagnosticsSnapshot snapshotValue;
  List<ClientErrorReport> errors;
  Failure? error;

  @override
  Future<DiagnosticsSnapshot> snapshot() async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return snapshotValue;
  }

  @override
  Future<List<ClientErrorReport>> clientErrors({
    int limit = 50,
    int days = 7,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return List.of(errors);
  }
}

DiagnosticsSnapshot sampleSnapshot({
  int staleSessions = 0,
  int deadPush = 0,
  int clientErrors = 0,
}) => DiagnosticsSnapshot(
  migrations: 36,
  lastMigrationAt: DateTime.utc(2026, 10, 24),
  lots: 2,
  activeLots: 2,
  openSessions: 3,
  staleSessions24h: staleSessions,
  openShifts12h: 0,
  pendingPassPayments: 1,
  activeReservations: 0,
  pendingPush: 0,
  deadPush: deadPush,
  unreadNotifications: 4,
  totalNotifications: 10,
  clientErrors24h: clientErrors,
  idempotencyKeys: 12,
  storage: const [
    StorageUsage(bucket: 'evidence', objects: 5, bytes: 2048),
  ],
);

ClientErrorReport sampleError({int id = 1}) => ClientErrorReport(
  id: id,
  platform: 'android',
  message: 'Bad state: boom',
  createdAt: DateTime.utc(2026, 10, 24, 10),
  stack: '#0 main',
  context: const {'kind': 'uncaught'},
  actor: 'admin',
);
