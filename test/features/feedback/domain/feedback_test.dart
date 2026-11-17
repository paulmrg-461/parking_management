import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_invite.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_summary.dart';

void main() {
  group('FeedbackInvite', () {
    test('Success: parses the public lookup payload', () {
      final invite = FeedbackInvite.fromJson({
        'lot_id': 1,
        'lot_name': 'Parqueadero Central',
        'rateable': true,
        'rated': false,
        'rating': null,
      });

      expect(invite.lotId, 1);
      expect(invite.lotName, 'Parqueadero Central');
      expect(invite.rateable, isTrue);
      expect(invite.rated, isFalse);
      expect(invite.rating, isNull);
    });

    test('Failure: missing optional keys fall back safely', () {
      final invite = FeedbackInvite.fromJson(const {});

      expect(invite.lotId, 0);
      expect(invite.lotName, '');
      expect(invite.rateable, isFalse);
      expect(invite.rated, isFalse);
      expect(invite.rating, isNull);
    });

    test('Success: an existing rating is parsed', () {
      final invite = FeedbackInvite.fromJson({
        'lot_id': 2,
        'lot_name': 'Norte',
        'rateable': true,
        'rated': true,
        'rating': 4,
      });

      expect(invite.rated, isTrue);
      expect(invite.rating, 4);
    });
  });

  group('FeedbackSummary', () {
    Map<String, dynamic> payload() => {
      'days': 30,
      'start_date': '2026-10-19',
      'end_date': '2026-11-17',
      'timezone': 'America/Bogota',
      'total': 12,
      'average_x10': 43,
      'closed_sessions': 300,
      'response_rate_bp': 400,
      'low_count': 3,
      'distribution': {'1': 1, '2': 0, '3': 2, '4': 4, '5': 5},
      'recent': [
        {
          'id': 7,
          'session_id': 55,
          'plate': 'MJS368',
          'rating': 5,
          'comment': 'Muy rápido',
          'created_at': '2026-11-16T18:04:00Z',
        },
      ],
    };

    test('Success: parses the documented report payload', () {
      final summary = FeedbackSummary.fromJson(payload());

      expect(summary.days, 30);
      expect(summary.total, 12);
      expect(summary.averageX10, 43);
      expect(summary.average, 4.3);
      expect(summary.responseRateBp, 400);
      expect(summary.responseRatePercent, 4);
      expect(summary.lowCount, 3);
      expect(summary.countFor(5), 5);
      expect(summary.peak, 5);
      expect(summary.recent.single.plate, 'MJS368');
      expect(summary.recent.single.comment, 'Muy rápido');
      expect(summary.recent.single.createdAt.isUtc, isTrue);
      expect(summary.timezone, 'America/Bogota');
      expect(summary.startDate, DateTime(2026, 10, 19));
    });

    test('Failure: a missing bucket still reports the five keys', () {
      final summary = FeedbackSummary.fromJson({
        'total': 2,
        'distribution': {'5': 1},
      });

      expect(summary.distribution.keys.toSet(), {1, 2, 3, 4, 5});
      expect(summary.countFor(1), 0);
      expect(summary.countFor(5), 1);
      expect(summary.recent, isEmpty);
      expect(summary.timezone, '');
    });

    test('Failure: unknown keys and non-numeric values are ignored', () {
      final summary = FeedbackSummary.fromJson({
        'total': 'many',
        'distribution': {'6': 4, 'x': 1, '3': 2},
      });

      expect(summary.total, 0);
      expect(summary.countFor(3), 2);
      expect(summary.countFor(5), 0);
    });

    test('Success: the empty placeholder has no answers', () {
      final summary = FeedbackSummary.empty(7);

      expect(summary.isEmpty, isTrue);
      expect(summary.days, 7);
      expect(summary.peak, 1);
      expect(summary.averageX10, 0);
    });

    test('Success: response rate rounds to the nearest percent', () {
      final summary = FeedbackSummary.fromJson({'response_rate_bp': 3350});

      expect(summary.responseRatePercent, 34);
    });
  });
}
