import 'package:equatable/equatable.dart';

/// One photo or video of a session, behind a short-lived signed URL.
class EvidenceMedia extends Equatable {
  const EvidenceMedia({
    required this.url,
    required this.takenAt,
    this.durationSeconds,
  });

  final String url;
  final DateTime takenAt;
  final int? durationSeconds;

  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  factory EvidenceMedia.fromJson(Map<String, dynamic> json) => EvidenceMedia(
    url: json['url'] as String,
    takenAt: DateTime.parse(json['taken_at'] as String),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [url, takenAt, durationSeconds];
}

/// Public (plate-keyed) view of a session's evidence.
class PublicEvidence extends Equatable {
  const PublicEvidence({
    required this.plate,
    required this.entryTime,
    this.exitTime,
    this.status = 'open',
    this.photos = const [],
    this.videos = const [],
  });

  final String plate;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status;
  final List<EvidenceMedia> photos;
  final List<EvidenceMedia> videos;

  bool get isEmpty => photos.isEmpty && videos.isEmpty;

  factory PublicEvidence.fromJson(Map<String, dynamic> json) => PublicEvidence(
    plate: json['plate'] as String,
    entryTime: DateTime.parse(json['entry_time'] as String),
    exitTime: json['exit_time'] == null
        ? null
        : DateTime.parse(json['exit_time'] as String),
    status: json['status'] as String? ?? 'open',
    photos: [
      for (final item in (json['photos'] as List<dynamic>? ?? const []))
        EvidenceMedia.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    videos: [
      for (final item in (json['videos'] as List<dynamic>? ?? const []))
        EvidenceMedia.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  @override
  List<Object?> get props => [
    plate,
    entryTime,
    exitTime,
    status,
    photos,
    videos,
  ];
}
