import 'package:equatable/equatable.dart';

enum DamageOverall {
  none,
  possible,
  insufficient;

  static DamageOverall parse(String? value) => switch (value) {
    'no_new_damage' => DamageOverall.none,
    'possible_new_damage' => DamageOverall.possible,
    _ => DamageOverall.insufficient,
  };
}

enum DamageStatus {
  pending,
  completed,
  failed;

  static DamageStatus parse(String? value) => switch (value) {
    'completed' => DamageStatus.completed,
    'failed' => DamageStatus.failed,
    _ => DamageStatus.pending,
  };
}

enum FindingClassification {
  preExisting,
  newDamage,
  uncertain;

  static FindingClassification parse(String? value) => switch (value) {
    'pre_existing' => FindingClassification.preExisting,
    'new' => FindingClassification.newDamage,
    _ => FindingClassification.uncertain,
  };
}

enum DamageZone {
  front,
  rear,
  left,
  right,
  roof,
  wheels,
  windows,
  interior,
  other;

  static DamageZone parse(String? value) => DamageZone.values.firstWhere(
    (zone) => zone.name == value,
    orElse: () => DamageZone.other,
  );
}

enum FindingReview {
  open,
  confirmed,
  dismissed;

  static FindingReview parse(String? value) => switch (value) {
    'confirmed' => FindingReview.confirmed,
    'dismissed' => FindingReview.dismissed,
    _ => FindingReview.open,
  };
}

class DamageFinding extends Equatable {
  const DamageFinding({
    required this.id,
    this.position = 0,
    this.zone = DamageZone.other,
    this.description = '',
    this.classification = FindingClassification.uncertain,
    this.confidence = 'low',
    this.downgradedFrom,
    this.entryPhotoIds = const [],
    this.exitPhotoIds = const [],
    this.reviewStatus = FindingReview.open,
    this.reviewNote,
    this.reviewedByName,
    this.reviewedAt,
  });

  final int id;
  final int position;
  final DamageZone zone;
  final String description;
  final FindingClassification classification;
  final String confidence;
  final String? downgradedFrom;
  final List<int> entryPhotoIds;
  final List<int> exitPhotoIds;
  final FindingReview reviewStatus;
  final String? reviewNote;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  bool get isDowngraded => downgradedFrom == 'new';

  factory DamageFinding.fromJson(Map<String, dynamic> json) => DamageFinding(
    id: (json['id'] as num?)?.toInt() ?? 0,
    position: (json['position'] as num?)?.toInt() ?? 0,
    zone: DamageZone.parse(json['zone'] as String?),
    description: json['description'] as String? ?? '',
    classification: FindingClassification.parse(json['classification'] as String?),
    confidence: json['confidence'] as String? ?? 'low',
    downgradedFrom: json['downgraded_from'] as String?,
    entryPhotoIds: [
      for (final id in (json['entry_photo_ids'] as List? ?? const []))
        (id as num).toInt(),
    ],
    exitPhotoIds: [
      for (final id in (json['exit_photo_ids'] as List? ?? const []))
        (id as num).toInt(),
    ],
    reviewStatus: FindingReview.parse(json['review_status'] as String?),
    reviewNote: json['review_note'] as String?,
    reviewedByName: json['reviewed_by_name'] as String?,
    reviewedAt: DateTime.tryParse(json['reviewed_at'] as String? ?? ''),
  );

  DamageFinding copyWith({FindingReview? reviewStatus, String? reviewNote}) =>
      DamageFinding(
        id: id,
        position: position,
        zone: zone,
        description: description,
        classification: classification,
        confidence: confidence,
        downgradedFrom: downgradedFrom,
        entryPhotoIds: entryPhotoIds,
        exitPhotoIds: exitPhotoIds,
        reviewStatus: reviewStatus ?? this.reviewStatus,
        reviewNote: reviewNote ?? this.reviewNote,
        reviewedByName: reviewedByName,
        reviewedAt: reviewedAt,
      );

  @override
  List<Object?> get props => [
    id, position, zone, description, classification, confidence,
    downgradedFrom, entryPhotoIds, exitPhotoIds, reviewStatus, reviewNote,
    reviewedByName, reviewedAt,
  ];
}

class DamageComparison extends Equatable {
  const DamageComparison({
    required this.id,
    this.runNumber = 1,
    this.status = DamageStatus.pending,
    this.overall = DamageOverall.insufficient,
    this.summary = '',
    this.quality = const {},
    this.model,
    this.entryPhotoCount = 0,
    this.exitPhotoCount = 0,
    this.errorCode,
    this.createdAt,
    this.completedAt,
    this.findings = const [],
  });

  final int id;
  final int runNumber;
  final DamageStatus status;
  final DamageOverall overall;
  final String summary;
  final Map<String, dynamic> quality;
  final String? model;
  final int entryPhotoCount;
  final int exitPhotoCount;
  final String? errorCode;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<DamageFinding> findings;

  bool get sameVehicleDoubt => quality['same_vehicle'] == 'no';

  factory DamageComparison.fromJson(Map<String, dynamic> json) =>
      DamageComparison(
        id: (json['id'] as num?)?.toInt() ?? 0,
        runNumber: (json['run_number'] as num?)?.toInt() ?? 1,
        status: DamageStatus.parse(json['status'] as String?),
        overall: DamageOverall.parse(json['overall'] as String?),
        summary: json['summary'] as String? ?? '',
        quality: json['quality'] is Map
            ? Map<String, dynamic>.from(json['quality'] as Map)
            : const {},
        model: json['model'] as String?,
        entryPhotoCount: (json['entry_photo_count'] as num?)?.toInt() ?? 0,
        exitPhotoCount: (json['exit_photo_count'] as num?)?.toInt() ?? 0,
        errorCode: json['error_code'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
        findings: [
          for (final item in (json['findings'] as List? ?? const []))
            if (item is Map)
              DamageFinding.fromJson(Map<String, dynamic>.from(item)),
        ],
      );

  @override
  List<Object?> get props => [
    id, runNumber, status, overall, summary, quality, model,
    entryPhotoCount, exitPhotoCount, errorCode, createdAt, completedAt, findings,
  ];
}

class DamageView extends Equatable {
  const DamageView({
    required this.sessionId,
    this.runs = 0,
    this.stale = false,
    this.comparison,
  });

  final int sessionId;
  final int runs;
  final bool stale;
  final DamageComparison? comparison;

  factory DamageView.fromJson(Map<String, dynamic> json) => DamageView(
    sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
    runs: (json['runs'] as num?)?.toInt() ?? 0,
    stale: json['stale'] as bool? ?? false,
    comparison: json['comparison'] is Map
        ? DamageComparison.fromJson(
            Map<String, dynamic>.from(json['comparison'] as Map),
          )
        : null,
  );

  @override
  List<Object?> get props => [sessionId, runs, stale, comparison];
}

class DamageAiStatus extends Equatable {
  const DamageAiStatus({
    this.configured = false,
    this.remainingRequests = 0,
  });

  final bool configured;
  final int remainingRequests;

  factory DamageAiStatus.fromJson(Map<String, dynamic> json) {
    final budget = json['budget'] is Map
        ? Map<String, dynamic>.from(json['budget'] as Map)
        : const <String, dynamic>{};
    return DamageAiStatus(
      configured: json['configured'] as bool? ?? false,
      remainingRequests: (budget['remaining_requests'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [configured, remainingRequests];
}
