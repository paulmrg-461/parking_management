import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/feedback/application/feedback_summary_cubit.dart';
import 'package:parking_management/features/feedback/application/public_feedback_cubit.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_invite.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_summary.dart';

import '../../../helpers/fake_feedback_repository.dart';

const _readyInvite = FeedbackInvite(
  lotId: 1,
  lotName: 'Parqueadero Central',
  rateable: true,
  rated: false,
);

FeedbackSummary _summary({int total = 2, int averageX10 = 45}) =>
    FeedbackSummary(
      days: 30,
      startDate: DateTime(2026, 10, 19),
      endDate: DateTime(2026, 11, 17),
      timezone: 'America/Bogota',
      total: total,
      averageX10: averageX10,
      closedSessions: 20,
      responseRateBp: 1000,
      lowCount: 0,
      distribution: const {1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
      recent: const [],
    );

void main() {
  group('PublicFeedbackCubit', () {
    test('Success: load exposes a rateable invite', () async {
      final repository = FakeFeedbackRepository()
        ..inviteToReturn = _readyInvite;
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: 7, plate: ' ABC123 ');

      expect(cubit.state, isA<FeedbackReady>());
      expect(
        (cubit.state as FeedbackReady).invite.lotName,
        'Parqueadero Central',
      );
      expect(repository.lastInviteSessionId, 7);
      expect(repository.lastInvitePlate, 'ABC123');
    });

    test('Success: a rated invite reports the previous answer', () async {
      final repository = FakeFeedbackRepository()
        ..inviteToReturn = const FeedbackInvite(
          lotId: 1,
          lotName: 'Central',
          rateable: true,
          rated: true,
          rating: 5,
        );
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: 7, plate: 'ABC123');

      final state = cubit.state;
      expect(state, isA<FeedbackAlready>());
      expect((state as FeedbackAlready).rating, 5);
    });

    test('Failure: an unknown link is an informative state', () async {
      final repository = FakeFeedbackRepository()..inviteToReturn = null;
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: 7, plate: 'ABC123');

      expect(cubit.state, isA<FeedbackInvalidLink>());
    });

    test('Failure: no session id never calls the server', () async {
      final repository = FakeFeedbackRepository();
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: null, plate: 'ABC123');

      expect(cubit.state, isA<FeedbackInvalidLink>());
      expect(repository.inviteCalls, 0);
    });

    test('Failure: an open session is not rateable', () async {
      final repository = FakeFeedbackRepository()
        ..inviteToReturn = const FeedbackInvite(
          lotId: 1,
          lotName: 'Central',
          rateable: false,
          rated: false,
        );
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: 7, plate: 'ABC123');

      expect(cubit.state, isA<FeedbackNotRateable>());
    });

    test('Failure: a load failure can be retried', () async {
      final repository = FakeFeedbackRepository()
        ..inviteError = const NetworkFailure();
      final cubit = PublicFeedbackCubit(repository);

      await cubit.load(sessionId: 7, plate: 'ABC123');
      expect(cubit.state, isA<FeedbackFailure>());

      repository
        ..inviteError = null
        ..inviteToReturn = _readyInvite;
      await cubit.load(sessionId: 7, plate: 'ABC123');
      expect(cubit.state, isA<FeedbackReady>());
    });

    test('Success: submit stores the rating and clears the form', () async {
      final repository = FakeFeedbackRepository()
        ..inviteToReturn = _readyInvite
        ..submitToReturn = 4;
      final cubit = PublicFeedbackCubit(repository);
      await cubit.load(sessionId: 7, plate: 'ABC123');

      await cubit.submit(rating: 4, comment: '  Buen servicio  ');

      expect(cubit.state, isA<FeedbackSubmitted>());
      expect((cubit.state as FeedbackSubmitted).rating, 4);
      expect(repository.lastRating, 4);
      expect(repository.lastComment, 'Buen servicio');
    });

    test('Failure: a duplicate switches to the already-rated state', () async {
      final repository = FakeFeedbackRepository()
        ..inviteToReturn = _readyInvite
        ..submitError = const ValidationFailure(
          'duplicate',
          'FeedbackAlreadyError',
        );
      final cubit = PublicFeedbackCubit(repository);
      await cubit.load(sessionId: 7, plate: 'ABC123');

      await cubit.submit(rating: 4);

      expect(cubit.state, isA<FeedbackAlready>());
    });

    test(
      'Failure: a retryable submit keeps the ready state and the error',
      () async {
        final repository = FakeFeedbackRepository()
          ..inviteToReturn = _readyInvite
          ..submitError = const NetworkFailure('down');
        final cubit = PublicFeedbackCubit(repository);
        await cubit.load(sessionId: 7, plate: 'ABC123');

        await cubit.submit(rating: 4, comment: 'Bueno');

        final state = cubit.state as FeedbackReady;
        expect(state.submitting, isFalse);
        expect(state.failure, isA<NetworkFailure>());
        expect(repository.submitCalls, 1);
      },
    );

    test('Security: submit before load is ignored', () async {
      final repository = FakeFeedbackRepository();
      final cubit = PublicFeedbackCubit(repository);

      await cubit.submit(rating: 5);

      expect(repository.submitCalls, 0);
    });
  });

  group('FeedbackSummaryCubit', () {
    test('Success: first load shows the skeleton then the summary', () async {
      final repository = FakeFeedbackRepository()..summaryToReturn = _summary();
      final cubit = FeedbackSummaryCubit(repository);
      final states = <FeedbackSummaryState>[];
      cubit.stream.listen(states.add);

      await cubit.load(7);
      await Future<void>.delayed(Duration.zero);

      expect(states.first, isA<FeedbackSummaryLoading>());
      expect(cubit.state, isA<FeedbackSummaryLoaded>());
      expect(repository.lastDays, 7);
      final loaded = cubit.state as FeedbackSummaryLoaded;
      expect(loaded.days, 7);
      expect(loaded.summary.averageX10, 45);
      expect(loaded.refreshing, isFalse);
    });

    test('Success: switching the period never flashes the skeleton', () async {
      final repository = FakeFeedbackRepository()..summaryToReturn = _summary();
      final cubit = FeedbackSummaryCubit(repository);
      await cubit.load(30);
      final states = <FeedbackSummaryState>[];
      cubit.stream.listen(states.add);

      await cubit.load(7);
      await Future<void>.delayed(Duration.zero);

      expect(states.first, isA<FeedbackSummaryLoaded>());
      expect((states.first as FeedbackSummaryLoaded).days, 7);
      expect((states.first as FeedbackSummaryLoaded).refreshing, isTrue);
      expect(states.last, isA<FeedbackSummaryLoaded>());
      expect((states.last as FeedbackSummaryLoaded).refreshing, isFalse);
    });

    test('Failure: an error exposes the typed failure and retries', () async {
      final repository = FakeFeedbackRepository()
        ..summaryError = const ServerFailure('down');
      final cubit = FeedbackSummaryCubit(repository);

      await cubit.load();
      expect(cubit.state, isA<FeedbackSummaryFailure>());

      repository
        ..summaryError = null
        ..summaryToReturn = _summary();
      await cubit.load();
      expect(cubit.state, isA<FeedbackSummaryLoaded>());
    });

    test('Failure: an empty period is still a loaded summary', () async {
      final repository = FakeFeedbackRepository();
      final cubit = FeedbackSummaryCubit(repository);

      await cubit.load();

      final loaded = cubit.state as FeedbackSummaryLoaded;
      expect(loaded.summary.isEmpty, isTrue);
    });
  });
}
