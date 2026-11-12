import 'package:equatable/equatable.dart';

enum EvidenceKind {
  photo,
  video;

  static EvidenceKind fromWire(Object? raw) =>
      raw == 'video' ? EvidenceKind.video : EvidenceKind.photo;
}

/// One evidence file of a parking session (check-in photo or walk-around
/// video). [url] is a short-lived signed URL, `null` when it could not be
/// signed (the tile still shows as unavailable instead of hiding the row).
class SessionEvidence extends Equatable {
  const SessionEvidence({
    required this.id,
    required this.path,
    required this.kind,
    required this.takenAt,
    this.durationSeconds,
    this.url,
  });

  final int id;
  final String path;
  final EvidenceKind kind;
  final DateTime takenAt;
  final int? durationSeconds;
  final String? url;

  bool get isVideo => kind == EvidenceKind.video;
  bool get isAvailable => url != null && url!.isNotEmpty;

  factory SessionEvidence.fromJson(Map<String, dynamic> json) {
    final rawDate = json['taken_at'];
    return SessionEvidence(
      id: (json['id'] as num?)?.toInt() ?? 0,
      path: json['file_path'] as String? ?? '',
      kind: EvidenceKind.fromWire(json['kind']),
      takenAt: rawDate is String && rawDate.isNotEmpty
          ? DateTime.tryParse(rawDate)?.toLocal() ?? DateTime(1970)
          : DateTime(1970),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      url: json['url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, path, kind, takenAt, durationSeconds, url];
}
