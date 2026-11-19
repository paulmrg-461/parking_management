import '../domain/entities/feedback_invite.dart';
import '../domain/entities/feedback_summary.dart';
import '../domain/repositories/feedback_repository.dart';
import 'feedback_remote_data_source.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl(this._remote);

  final FeedbackRemoteDataSource _remote;

  @override
  Future<FeedbackInvite?> invite({
    required int sessionId,
    required String plate,
  }) => _remote.invite(sessionId: sessionId, plate: plate);

  @override
  Future<int> submit({
    required int sessionId,
    required String plate,
    required int rating,
    String comment = '',
  }) => _remote.submit(
    sessionId: sessionId,
    plate: plate,
    rating: rating,
    comment: comment,
  );

  @override
  Future<FeedbackSummary> summary(int days) => _remote.summary(days);
}
