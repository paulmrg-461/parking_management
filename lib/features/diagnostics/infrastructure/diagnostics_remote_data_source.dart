import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/client_error_report.dart';
import '../domain/entities/diagnostics_snapshot.dart';

abstract class DiagnosticsRemoteDataSource {
  Future<DiagnosticsSnapshot> snapshot();

  Future<List<ClientErrorReport>> clientErrors({
    required int limit,
    required int days,
  });
}

class SupabaseDiagnosticsRemoteDataSource
    implements DiagnosticsRemoteDataSource {
  SupabaseDiagnosticsRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<DiagnosticsSnapshot> snapshot() async {
    try {
      final result = await _client.rpc('diagnostics_snapshot');
      return DiagnosticsSnapshot.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<ClientErrorReport>> clientErrors({
    required int limit,
    required int days,
  }) async {
    try {
      final result = await _client.rpc(
        'list_client_error_reports',
        params: {'p_limit': limit, 'p_days': days},
      );
      return [
        for (final item in (result as List<dynamic>? ?? const []))
          ClientErrorReport.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
