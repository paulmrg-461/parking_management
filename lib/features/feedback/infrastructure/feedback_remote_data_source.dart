import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/feedback_invite.dart';
import '../domain/entities/feedback_summary.dart';

abstract class FeedbackRemoteDataSource {
  Future<FeedbackInvite?> invite({
    required int sessionId,
    required String plate,
  });

  Future<int> submit({
    required int sessionId,
    required String plate,
    required int rating,
    required String comment,
  });

  Future<FeedbackSummary> summary(int days);
}

class SupabaseFeedbackRemoteDataSource implements FeedbackRemoteDataSource {
  SupabaseFeedbackRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<FeedbackInvite?> invite({
    required int sessionId,
    required String plate,
  }) async {
    try {
      final result = await _client.rpc(
        'public_feedback_session',
        params: {'p_session_id': sessionId, 'p_plate': plate},
      );
      if (result is! Map) {
        return null;
      }
      return FeedbackInvite.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<int> submit({
    required int sessionId,
    required String plate,
    required int rating,
    required String comment,
  }) async {
    try {
      final result = await _client.rpc(
        'public_submit_feedback',
        params: {
          'p_session_id': sessionId,
          'p_plate': plate,
          'p_rating': rating,
          'p_comment': comment,
        },
      );
      if (result is Map) {
        return ((result)['rating'] as num?)?.toInt() ?? rating;
      }
      return rating;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FeedbackSummary> summary(int days) async {
    try {
      final result = await _client.rpc(
        'feedback_summary',
        params: {'p_days': days},
      );
      if (result is! Map) {
        return FeedbackSummary.empty(days);
      }
      return FeedbackSummary.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
