import '../entities/audit_entry.dart';

abstract class AuditRepository {
  Future<List<AuditEntry>> list({
    int limit = 100,
    DateTime? from,
    DateTime? to,
    String? table,
    String? actor,
  });
}
