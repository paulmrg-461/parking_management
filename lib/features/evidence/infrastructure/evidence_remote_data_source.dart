import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/public_evidence.dart';

abstract class EvidenceRemoteDataSource {
  Future<PublicEvidence> fetch({
    required int sessionId,
    required String plate,
  });
}

class SupabaseEvidenceRemoteDataSource implements EvidenceRemoteDataSource {
  SupabaseEvidenceRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PublicEvidence> fetch({
    required int sessionId,
    required String plate,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'public-evidence',
        body: {'session': sessionId, 'plate': plate},
      );
      final data = response.data;
      if (data is! Map) {
        throw const ValidationFailure(
          'Evidence not available',
          'EvidenceNotFoundError',
        );
      }
      return PublicEvidence.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      if (error.status == 400 || error.status == 404) {
        throw const ValidationFailure(
          'Evidence not available',
          'EvidenceNotFoundError',
        );
      }
      throw code == 'evidence_unavailable'
          ? const ServerFailure('Evidence not available')
          : mapSupabaseError(error);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
