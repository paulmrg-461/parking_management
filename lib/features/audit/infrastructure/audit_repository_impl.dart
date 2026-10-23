import '../domain/entities/audit_entry.dart';
import '../domain/repositories/audit_repository.dart';
import 'audit_remote_data_source.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._remote);

  final AuditRemoteDataSource _remote;

  @override
  Future<List<AuditEntry>> list({
    int limit = 100,
    DateTime? from,
    DateTime? to,
    String? table,
  }) => _remote.list(limit: limit, from: from, to: to, table: table);
}
