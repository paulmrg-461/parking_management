import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/audit_entry.dart';

abstract class AuditRemoteDataSource {
  Future<List<AuditEntry>> list({
    required int limit,
    DateTime? from,
    DateTime? to,
    String? table,
  });
}

class SupabaseAuditRemoteDataSource implements AuditRemoteDataSource {
  SupabaseAuditRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AuditEntry>> list({
    required int limit,
    DateTime? from,
    DateTime? to,
    String? table,
  }) async {
    try {
      final result = await _client.rpc(
        'list_audit_log',
        params: {
          'p_limit': limit,
          if (from != null) 'p_start_date': _date(from),
          if (to != null) 'p_end_date': _date(to),
          'p_table': ?table,
        },
      );
      return [
        for (final item in (result as List<dynamic>? ?? const []))
          AuditEntry.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
