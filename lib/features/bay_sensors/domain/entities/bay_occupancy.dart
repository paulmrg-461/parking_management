import 'package:equatable/equatable.dart';

enum BayState {
  free,
  occupied,
  unknown;

  static BayState fromWire(Object? wire) => switch (wire) {
    'free' => BayState.free,
    'occupied' => BayState.occupied,
    _ => BayState.unknown,
  };
}

enum BayHealth {
  ok,
  stale,
  fault,
  flapping,
  unmapped,
  neverSeen;

  static BayHealth parse(Object? wire) => switch (wire) {
    'stale' => BayHealth.stale,
    'fault' => BayHealth.fault,
    'flapping' => BayHealth.flapping,
    'unmapped' => BayHealth.unmapped,
    'never_seen' => BayHealth.neverSeen,
    _ => BayHealth.ok,
  };
}

enum BayMismatchKind {
  occupiedUnassigned,
  assignedEmpty,
  occupiedOutOfService;

  static BayMismatchKind parse(Object? wire) => switch (wire) {
    'occupied_unassigned' => BayMismatchKind.occupiedUnassigned,
    'assigned_empty' => BayMismatchKind.assignedEmpty,
    'occupied_out_of_service' => BayMismatchKind.occupiedOutOfService,
    _ => throw const FormatException('unknown bay mismatch kind'),
  };
}

class BayReading extends Equatable {
  const BayReading({
    required this.spotId,
    required this.code,
    required this.state,
    required this.health,
    this.mismatch,
  });

  factory BayReading.fromJson(Map<String, dynamic> json) => BayReading(
    spotId: (json['spot_id'] as num).toInt(),
    code: json['code'] as String? ?? '',
    state: BayState.fromWire(json['state']),
    health: BayHealth.parse(json['health']),
    mismatch: json['mismatch'] == null
        ? null
        : BayMismatchKind.parse(json['mismatch']),
  );

  final int spotId;
  final String code;
  final BayState state;
  final BayHealth health;
  final BayMismatchKind? mismatch;

  @override
  List<Object?> get props => [spotId, code, state, health, mismatch];
}

class BayMismatch extends Equatable {
  const BayMismatch({
    required this.id,
    required this.spotId,
    required this.code,
    required this.kind,
    required this.openedAt,
    this.sessionId,
    this.plate,
  });

  factory BayMismatch.fromJson(Map<String, dynamic> json) => BayMismatch(
    id: (json['id'] as num).toInt(),
    spotId: (json['spot_id'] as num).toInt(),
    code: json['code'] as String? ?? '',
    kind: BayMismatchKind.parse(json['kind']),
    sessionId: (json['session_id'] as num?)?.toInt(),
    plate: json['plate'] as String?,
    openedAt:
        DateTime.tryParse(json['opened_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  final int id;
  final int spotId;
  final String code;
  final BayMismatchKind kind;
  final int? sessionId;
  final String? plate;
  final DateTime openedAt;

  @override
  List<Object?> get props => [id, spotId, code, kind, sessionId, plate, openedAt];
}

class BayOccupancy extends Equatable {
  const BayOccupancy({
    required this.sensorsEnabled,
    required this.bays,
    required this.mismatches,
  });

  factory BayOccupancy.fromJson(Map<String, dynamic> json) => BayOccupancy(
    sensorsEnabled: json['sensors_enabled'] as bool? ?? false,
    bays: [
      for (final item in (json['bays'] as List? ?? const []))
        if (item is Map) BayReading.fromJson(Map<String, dynamic>.from(item)),
    ],
    mismatches: [
      for (final item in (json['mismatches'] as List? ?? const []))
        if (item is Map) BayMismatch.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  static const empty = BayOccupancy(
    sensorsEnabled: false,
    bays: [],
    mismatches: [],
  );

  final bool sensorsEnabled;
  final List<BayReading> bays;
  final List<BayMismatch> mismatches;

  BayReading? of(int spotId) {
    for (final bay in bays) {
      if (bay.spotId == spotId) return bay;
    }
    return null;
  }

  @override
  List<Object?> get props => [sensorsEnabled, bays, mismatches];
}
