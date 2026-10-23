import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/audit/domain/entities/audit_entry.dart';
import 'package:parking_management/features/audit/domain/repositories/audit_repository.dart';

class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository([List<AuditEntry> entries = const []])
    : entries = List.of(entries);

  List<AuditEntry> entries;
  Failure? error;
  DateTime? lastFrom;
  DateTime? lastTo;
  String? lastTable;

  @override
  Future<List<AuditEntry>> list({
    int limit = 100,
    DateTime? from,
    DateTime? to,
    String? table,
  }) async {
    lastFrom = from;
    lastTo = to;
    lastTable = table;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return List.of(entries);
  }
}

AuditEntry sampleAudit({
  int id = 1,
  String action = 'update',
  String table = 'tariffs',
  String? actor = 'admin',
  String? lot = 'Central',
}) => AuditEntry(
  id: id,
  action: action,
  tableName: table,
  createdAt: DateTime.utc(2026, 10, 23, 12),
  actor: actor,
  entityId: '3',
  lot: lot,
  before: const {'amount': 5000},
  after: const {'amount': 6000},
);
