import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/session_evidence.dart';

abstract class SessionEvidenceRemoteDataSource {
  Future<List<SessionEvidence>> listForSession(int sessionId);
}

class SupabaseSessionEvidenceRemoteDataSource
    implements SessionEvidenceRemoteDataSource {
  SupabaseSessionEvidenceRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'evidence_photos';
  static const _bucket = 'evidence';

  /// One hour is enough for a viewing session; the next open signs again.
  static const _signedSeconds = 3600;

  @override
  Future<List<SessionEvidence>> listForSession(int sessionId) async {
    try {
      final rows = await _client
          .from(_table)
          .select('id, file_path, kind, duration_seconds, taken_at')
          .eq('session_id', sessionId)
          .order('taken_at');
      final result = <SessionEvidence>[];
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final path = map['file_path'] as String? ?? '';
        String? url;
        if (path.isNotEmpty) {
          try {
            url = await _client.storage
                .from(_bucket)
                .createSignedUrl(path, _signedSeconds);
          } catch (_) {
            // Keep the row: the grid shows it as unavailable and the operator
            // still knows evidence was captured.
          }
        }
        result.add(SessionEvidence.fromJson({...map, 'url': url}));
      }
      return result;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
