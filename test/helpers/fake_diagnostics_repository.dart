import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/diagnostics/domain/entities/client_error_report.dart';
import 'package:parking_management/features/diagnostics/domain/entities/diagnostics_snapshot.dart';
import 'package:parking_management/features/diagnostics/domain/entities/whatsapp_message.dart';
import 'package:parking_management/features/diagnostics/domain/repositories/diagnostics_repository.dart';

class FakeDiagnosticsRepository implements DiagnosticsRepository {
  FakeDiagnosticsRepository({
    DiagnosticsSnapshot? snapshot,
    List<ClientErrorReport> errors = const [],
    List<WhatsappMessage> whatsapp = const [],
  }) : snapshotValue = snapshot ?? sampleSnapshot(),
       errors = List.of(errors),
       whatsapp = List.of(whatsapp);

  DiagnosticsSnapshot snapshotValue;
  List<ClientErrorReport> errors;
  List<WhatsappMessage> whatsapp;
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

  @override
  Future<List<WhatsappMessage>> whatsappMessages({
    int limit = 50,
    int days = 7,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return List.of(whatsapp);
  }
}

DiagnosticsSnapshot sampleSnapshot({
  int staleSessions = 0,
  int deadPush = 0,
  int clientErrors = 0,
  int whatsappFailed = 0,
  int whatsappPending = 0,
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
  whatsappPending: whatsappPending,
  whatsappFailed: whatsappFailed,
  whatsappSent24h: 2,
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

WhatsappMessage sampleWhatsapp({
  int id = 1,
  String status = 'failed',
  String? messageError = '401: invalid token',
}) => WhatsappMessage(
  id: id,
  toPhone: '573001112233',
  template: 'receipt',
  status: status,
  createdAt: DateTime.utc(2026, 10, 24, 10),
  attempts: 3,
  error: messageError,
  actor: 'admin',
  lot: 'Central',
);
