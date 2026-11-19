import 'package:equatable/equatable.dart';

/// What the public survey page needs about one visit (`public_feedback_session`).
///
/// `rateable` is false while the session is still open; `rated` says a rating
/// already exists (the page then shows the thank-you state instead of the form).
class FeedbackInvite extends Equatable {
  const FeedbackInvite({
    required this.lotId,
    required this.lotName,
    required this.rateable,
    required this.rated,
    this.rating,
  });

  final int lotId;
  final String lotName;
  final bool rateable;
  final bool rated;
  final int? rating;

  factory FeedbackInvite.fromJson(Map<String, dynamic> json) => FeedbackInvite(
    lotId: (json['lot_id'] as num?)?.toInt() ?? 0,
    lotName: json['lot_name'] as String? ?? '',
    rateable: json['rateable'] as bool? ?? false,
    rated: json['rated'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [lotId, lotName, rateable, rated, rating];
}
