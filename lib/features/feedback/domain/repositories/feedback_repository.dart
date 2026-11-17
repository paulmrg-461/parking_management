import '../entities/feedback_invite.dart';
import '../entities/feedback_summary.dart';

/// Customer feedback. Remote only: the server verifies the session, the plate
/// and the one-answer rule, so nothing is ever queued in the outbox.
abstract class FeedbackRepository {
  /// `null` when the session does not exist or the plate does not match.
  Future<FeedbackInvite?> invite({
    required int sessionId,
    required String plate,
  });

  /// Stores the answer and returns the stored rating.
  Future<int> submit({
    required int sessionId,
    required String plate,
    required int rating,
    String comment = '',
  });

  Future<FeedbackSummary> summary(int days);
}
