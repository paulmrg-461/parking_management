import 'package:equatable/equatable.dart';

import '../../../spots/domain/entities/parking_spot.dart';

/// Space group used by the visual board and the capacity settings.
enum SlotGroup {
  car,
  moto,
  heavy;

  static SlotGroup fromWire(Object? value) => switch (value) {
    'car' => SlotGroup.car,
    'moto' => SlotGroup.moto,
    _ => SlotGroup.heavy,
  };
}

/// A car currently inside, as painted on the board.
class SlotSession extends Equatable {
  const SlotSession({
    required this.sessionId,
    required this.plate,
    required this.entryTime,
    this.spotId,
    this.videoCount = 0,
    this.hasPass = false,
    this.leftKeys = false,
    this.photoCount = 0,
    this.group = SlotGroup.car,
  });

  final int sessionId;
  final String plate;
  final DateTime entryTime;

  /// Physical bay assigned at check-in (null when the site has no map).
  final int? spotId;
  final int videoCount;
  final bool hasPass;
  final bool leftKeys;
  final int photoCount;
  final SlotGroup group;

  factory SlotSession.fromJson(Map<String, dynamic> json) => SlotSession(
    sessionId: (json['session_id'] as num).toInt(),
    plate: json['plate'] as String,
    entryTime: DateTime.parse(json['entry_time'] as String),
    spotId: (json['spot_id'] as num?)?.toInt(),
    videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
    hasPass: json['has_pass'] == true,
    leftKeys: json['left_keys'] == true,
    photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
    group: SlotGroup.fromWire(json['group']),
  );

  @override
  List<Object?> get props => [
    sessionId,
    plate,
    entryTime,
    spotId,
    videoCount,
    hasPass,
    leftKeys,
    photoCount,
    group,
  ];
}

/// An active hold painted as a promised space.
class SlotHold extends Equatable {
  const SlotHold({
    required this.plate,
    required this.until,
    this.group = SlotGroup.car,
  });

  final String plate;
  final DateTime until;
  final SlotGroup group;

  factory SlotHold.fromJson(Map<String, dynamic> json) => SlotHold(
    plate: json['plate'] as String,
    until: DateTime.parse(json['reserved_until'] as String),
    group: SlotGroup.fromWire(json['group']),
  );

  @override
  List<Object?> get props => [plate, until, group];
}

/// Board data for the active site: capacities plus what is inside/held.
class SlotBoard extends Equatable {
  const SlotBoard({
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.carOutOfService = 0,
    this.motoOutOfService = 0,
    this.sessions = const [],
    this.holds = const [],
    this.spots = const [],
  });

  final int carCapacity;
  final int motoCapacity;

  /// Spots the admin took out of the usable pool (maintenance, blocked area).
  final int carOutOfService;
  final int motoOutOfService;
  final List<SlotSession> sessions;
  final List<SlotHold> holds;

  /// The site's physical map (empty until the admin lays it out).
  final List<ParkingSpot> spots;

  static const empty = SlotBoard();

  bool get isEmpty =>
      carCapacity == 0 &&
      motoCapacity == 0 &&
      sessions.isEmpty &&
      spots.isEmpty;

  bool get hasMap => spots.isNotEmpty;

  /// Sessions with no bay (the site had no map when they checked in).
  List<SlotSession> get unassignedSessions => [
    for (final session in sessions)
      if (session.spotId == null) session,
  ];

  SlotSession? sessionAt(ParkingSpot spot) {
    for (final session in sessions) {
      if (session.spotId == spot.id) {
        return session;
      }
    }
    return null;
  }

  List<SlotSession> sessionsIn(SlotGroup group) => [
    for (final session in sessions)
      if (session.group == group) session,
  ];

  List<SlotHold> holdsIn(SlotGroup group) => [
    for (final hold in holds)
      if (hold.group == group) hold,
  ];

  factory SlotBoard.fromJson(Map<String, dynamic> json) => SlotBoard(
    carCapacity: (json['car_capacity'] as num?)?.toInt() ?? 0,
    motoCapacity: (json['moto_capacity'] as num?)?.toInt() ?? 0,
    carOutOfService: (json['car_out_of_service'] as num?)?.toInt() ?? 0,
    motoOutOfService: (json['moto_out_of_service'] as num?)?.toInt() ?? 0,
    sessions: [
      for (final item in (json['sessions'] as List<dynamic>? ?? const []))
        SlotSession.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    holds: [
      for (final item in (json['holds'] as List<dynamic>? ?? const []))
        SlotHold.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    spots: [
      for (final item in (json['spots'] as List<dynamic>? ?? const []))
        ParkingSpot.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  int outOfServiceIn(SlotGroup group) => switch (group) {
    SlotGroup.car => carOutOfService,
    SlotGroup.moto => motoOutOfService,
    SlotGroup.heavy => 0,
  };

  @override
  List<Object?> get props => [
    carCapacity,
    motoCapacity,
    carOutOfService,
    motoOutOfService,
    sessions,
    holds,
    spots,
  ];
}
