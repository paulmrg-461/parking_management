import 'package:equatable/equatable.dart';

/// One status change of a physical bay (`rpc/list_spot_events`): who took it
/// out of service (or brought it back), when and why.
class SpotEvent extends Equatable {
  const SpotEvent({
    required this.id,
    required this.spotCode,
    required this.active,
    required this.createdAt,
    this.spotId,
    this.reason,
    this.actorName,
  });

  final int id;

  /// `null` when the bay was deleted after the event.
  final int? spotId;
  final String spotCode;

  /// `true` = active again, `false` = out of service.
  final bool active;
  final DateTime createdAt;
  final String? reason;
  final String? actorName;

  factory SpotEvent.fromJson(Map<String, dynamic> json) {
    final rawDate = json['created_at'];
    final rawReason = json['reason'];
    final rawActor = json['actor_name'];
    return SpotEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      spotId: (json['spot_id'] as num?)?.toInt(),
      spotCode: json['spot_code'] as String? ?? '',
      active: json['active'] != false,
      createdAt: rawDate is String && rawDate.isNotEmpty
          ? DateTime.tryParse(rawDate)?.toLocal() ?? DateTime(1970)
          : DateTime(1970),
      reason: rawReason is String && rawReason.trim().isNotEmpty
          ? rawReason
          : null,
      actorName: rawActor is String && rawActor.trim().isNotEmpty
          ? rawActor
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    spotId,
    spotCode,
    active,
    createdAt,
    reason,
    actorName,
  ];
}
