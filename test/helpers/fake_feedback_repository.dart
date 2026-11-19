import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_invite.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_summary.dart';
import 'package:parking_management/features/feedback/domain/repositories/feedback_repository.dart';

class FakeFeedbackRepository implements FeedbackRepository {
  FeedbackInvite? inviteToReturn;
  Failure? inviteError;
  int inviteCalls = 0;
  int? lastInviteSessionId;
  String? lastInvitePlate;

  int submitToReturn = 5;
  Failure? submitError;
  int submitCalls = 0;
  int? lastRating;
  String? lastComment;

  FeedbackSummary summaryToReturn = FeedbackSummary.empty();
  Failure? summaryError;
  int summaryCalls = 0;
  int? lastDays;

  @override
  Future<FeedbackInvite?> invite({
    required int sessionId,
    required String plate,
  }) async {
    inviteCalls++;
    lastInviteSessionId = sessionId;
    lastInvitePlate = plate;
    final error = inviteError;
    if (error != null) {
      throw error;
    }
    return inviteToReturn;
  }

  @override
  Future<int> submit({
    required int sessionId,
    required String plate,
    required int rating,
    String comment = '',
  }) async {
    submitCalls++;
    lastRating = rating;
    lastComment = comment;
    final error = submitError;
    if (error != null) {
      throw error;
    }
    return submitToReturn;
  }

  @override
  Future<FeedbackSummary> summary(int days) async {
    summaryCalls++;
    lastDays = days;
    final error = summaryError;
    if (error != null) {
      throw error;
    }
    return summaryToReturn;
  }
}
