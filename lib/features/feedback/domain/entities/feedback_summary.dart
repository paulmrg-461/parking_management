import 'package:equatable/equatable.dart';

/// One stored answer of the admin report.
class FeedbackEntry extends Equatable {
  const FeedbackEntry({
    required this.id,
    required this.sessionId,
    required this.plate,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final int id;
  final int sessionId;
  final String plate;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    id: _int(json['id']),
    sessionId: _int(json['session_id']),
    plate: json['plate'] as String? ?? '',
    rating: _int(json['rating']),
    comment: json['comment'] as String? ?? '',
    createdAt: _date(json['created_at']),
  );

  @override
  List<Object?> get props => [id, sessionId, plate, rating, comment, createdAt];
}

/// Admin satisfaction report (`feedback_summary`). Figures are integers on
/// purpose: [averageX10] is the average times ten (43 = 4.3) and
/// [responseRateBp] is basis points, so no float arithmetic happens anywhere.
class FeedbackSummary extends Equatable {
  const FeedbackSummary({
    required this.days,
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.total,
    required this.averageX10,
    required this.closedSessions,
    required this.responseRateBp,
    required this.lowCount,
    required this.distribution,
    required this.recent,
  });

  final int days;
  final DateTime startDate;
  final DateTime endDate;
  final String timezone;
  final int total;
  final int averageX10;
  final int closedSessions;
  final int responseRateBp;
  final int lowCount;

  /// Rating (1..5) to count. Always carries the five keys.
  final Map<int, int> distribution;
  final List<FeedbackEntry> recent;

  bool get isEmpty => total == 0;

  double get average => averageX10 / 10;

  /// Whole percent, rounded.
  int get responseRatePercent => (responseRateBp / 100).round();

  int countFor(int rating) => distribution[rating] ?? 0;

  /// Highest bucket, used to scale the bars (never zero).
  int get peak =>
      distribution.values.fold(1, (max, value) => value > max ? value : max);

  factory FeedbackSummary.fromJson(Map<String, dynamic> json) {
    final recent = json['recent'];
    return FeedbackSummary(
      days: _int(json['days']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      timezone: json['timezone'] as String? ?? '',
      total: _int(json['total']),
      averageX10: _int(json['average_x10']),
      closedSessions: _int(json['closed_sessions']),
      responseRateBp: _int(json['response_rate_bp']),
      lowCount: _int(json['low_count']),
      distribution: _distribution(json['distribution']),
      recent: [
        if (recent is List)
          for (final item in recent)
            if (item is Map)
              FeedbackEntry.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  /// Placeholder used while the page has nothing to show.
  static FeedbackSummary empty([int days = 30]) => FeedbackSummary(
    days: days,
    startDate: DateTime(2000),
    endDate: DateTime(2000),
    timezone: '',
    total: 0,
    averageX10: 0,
    closedSessions: 0,
    responseRateBp: 0,
    lowCount: 0,
    distribution: {for (var i = 1; i <= 5; i++) i: 0},
    recent: const [],
  );

  @override
  List<Object?> get props => [
    days,
    startDate,
    endDate,
    timezone,
    total,
    averageX10,
    closedSessions,
    responseRateBp,
    lowCount,
    distribution,
    recent,
  ];
}

Map<int, int> _distribution(Object? raw) {
  final result = {for (var i = 1; i <= 5; i++) i: 0};
  if (raw is Map) {
    for (final entry in raw.entries) {
      final rating = int.tryParse('${entry.key}');
      if (rating == null || rating < 1 || rating > 5) {
        continue;
      }
      result[rating] = _int(entry.value);
    }
  }
  return result;
}

int _int(Object? raw) => switch (raw) {
  num value => value.toInt(),
  String value => int.tryParse(value) ?? 0,
  _ => 0,
};

DateTime _date(Object? raw) =>
    DateTime.tryParse(raw?.toString() ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
