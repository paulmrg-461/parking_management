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

/// Contact/branding of the site shown on the public QR page.
class PublicLotContact extends Equatable {
  const PublicLotContact({
    required this.id,
    required this.name,
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.schedule = '',
    this.logoUrl,
  });

  final int id;
  final String name;
  final String phone;
  final String whatsapp;
  final String address;
  final String schedule;
  final String? logoUrl;

  bool get hasContact => phone.isNotEmpty || whatsapp.isNotEmpty;

  factory PublicLotContact.fromJson(Map<String, dynamic> json) =>
      PublicLotContact(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        address: json['address'] as String? ?? '',
        schedule: json['schedule'] as String? ?? '',
        logoUrl: json['logo_url'] as String?,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    whatsapp,
    address,
    schedule,
    logoUrl,
  ];
}

/// Duration and fare shown next to the evidence on the public QR page.
class PublicSessionSummary extends Equatable {
  const PublicSessionSummary({
    required this.sessionId,
    required this.status,
    required this.durationSeconds,
    required this.currency,
    required this.amount,
    this.hasPass = false,
  });

  final int sessionId;
  final String status;
  final int durationSeconds;
  final String currency;
  final int amount;
  final bool hasPass;

  Duration get duration => Duration(seconds: durationSeconds);
  bool get isOpen => status == 'open';

  factory PublicSessionSummary.fromJson(Map<String, dynamic> json) =>
      PublicSessionSummary(
        sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'open',
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'COP',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        hasPass: json['has_pass'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
    sessionId,
    status,
    durationSeconds,
    currency,
    amount,
    hasPass,
  ];
}

/// Public (plate-keyed) view of a session's evidence.
class PublicEvidence extends Equatable {
  const PublicEvidence({
    required this.plate,
    required this.entryTime,
    this.lotId,
    this.exitTime,
    this.status = 'open',
    this.photos = const [],
    this.videos = const [],
    this.summary,
    this.lot,
  });

  final String plate;
  final DateTime entryTime;

  /// Site that owns the session, for the public policy link.
  final int? lotId;
  final DateTime? exitTime;
  final String status;
  final List<EvidenceMedia> photos;
  final List<EvidenceMedia> videos;

  /// Duration/fare for the customer; null on older backends.
  final PublicSessionSummary? summary;

  /// Site name, logo and contact actions.
  final PublicLotContact? lot;

  bool get isEmpty => photos.isEmpty && videos.isEmpty;

  factory PublicEvidence.fromJson(Map<String, dynamic> json) => PublicEvidence(
    plate: json['plate'] as String,
    entryTime: DateTime.parse(json['entry_time'] as String),
    lotId: (json['lot_id'] as num?)?.toInt(),
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
    summary: json['summary'] is Map<String, dynamic>
        ? PublicSessionSummary.fromJson(
            Map<String, dynamic>.from(json['summary'] as Map),
          )
        : null,
    lot: json['lot'] is Map<String, dynamic>
        ? PublicLotContact.fromJson(
            Map<String, dynamic>.from(json['lot'] as Map),
          )
        : null,
  );

  @override
  List<Object?> get props => [
    plate,
    entryTime,
    lotId,
    exitTime,
    status,
    photos,
    videos,
    summary,
    lot,
  ];
}
