import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/session_record.dart';

abstract class RecordRemoteDataSource {
  Future<SessionRecordPage> list({
    required String plate,
    required int offset,
    required int limit,
  });
}

class SupabaseRecordRemoteDataSource implements RecordRemoteDataSource {
  SupabaseRecordRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<SessionRecordPage> list({
    required String plate,
    required int offset,
    required int limit,
  }) async {
    try {
      final result = await _client.rpc(
        'session_records',
        params: {
          'p_plate': plate.trim().isEmpty ? null : plate.trim(),
          'p_offset': offset,
          'p_limit': limit,
        },
      );
      final map = Map<String, dynamic>.from(result as Map);
      return SessionRecordPage(
        total: (map['total'] as num?)?.toInt() ?? 0,
        items: [
          for (final item in (map['records'] as List<dynamic>? ?? const []))
            SessionRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
