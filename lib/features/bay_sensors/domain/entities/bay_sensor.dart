import 'package:equatable/equatable.dart';

import 'bay_occupancy.dart';

enum BaySensorType {
  ultrasonic,
  magnetic,
  contact;

  static BaySensorType parse(Object? wire) => switch (wire) {
    'magnetic' => BaySensorType.magnetic,
    'contact' => BaySensorType.contact,
    _ => BaySensorType.ultrasonic,
  };

  String get unit => switch (this) {
    BaySensorType.ultrasonic => 'mm',
    BaySensorType.magnetic => 'uT',
    BaySensorType.contact => '',
  };
}

class BaySensor extends Equatable {
  const BaySensor({
    required this.id,
    required this.hubDeviceId,
    required this.hubName,
    required this.channel,
    required this.type,
    required this.state,
    required this.health,
    required this.threshold,
    required this.hysteresis,
    this.spotId,
    this.spotCode,
    this.lastReportAt,
    this.lastRaw,
    this.flapsLastHour = 0,
  });

  factory BaySensor.fromJson(Map<String, dynamic> json) => BaySensor(
    id: (json['sensor_id'] as num).toInt(),
    hubDeviceId: (json['hub_device_id'] as num?)?.toInt() ?? 0,
    hubName: json['hub_name'] as String? ?? '',
    channel: (json['channel'] as num?)?.toInt() ?? 0,
    spotId: (json['spot_id'] as num?)?.toInt(),
    spotCode: json['spot_code'] as String?,
    type: BaySensorType.parse(json['sensor_type']),
    state: BayState.fromWire(json['state']),
    health: BayHealth.parse(json['health']),
    threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
    hysteresis: (json['hysteresis'] as num?)?.toDouble() ?? 0,
    lastReportAt: DateTime.tryParse(json['last_report_at'] as String? ?? ''),
    lastRaw: (json['last_raw'] as num?)?.toDouble(),
    flapsLastHour: (json['flaps'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final int hubDeviceId;
  final String hubName;
  final int channel;
  final int? spotId;
  final String? spotCode;
  final BaySensorType type;
  final BayState state;
  final BayHealth health;
  final double threshold;
  final double hysteresis;
  final DateTime? lastReportAt;
  final double? lastRaw;
  final int flapsLastHour;

  bool get mapped => spotId != null;

  @override
  List<Object?> get props => [
    id,
    hubDeviceId,
    hubName,
    channel,
    spotId,
    spotCode,
    type,
    state,
    health,
    threshold,
    hysteresis,
    lastReportAt,
    lastRaw,
    flapsLastHour,
  ];
}

class BaySensorSettings extends Equatable {
  const BaySensorSettings({
    this.debounceSeconds = 20,
    this.staleMinutes = 5,
    this.flapPerHour = 12,
    this.mismatchGraceMinutes = 3,
    this.cooldownMinutes = 30,
  });

  factory BaySensorSettings.fromJson(Map<String, dynamic> json) =>
      BaySensorSettings(
        debounceSeconds: (json['debounce_seconds'] as num?)?.toInt() ?? 20,
        staleMinutes: (json['stale_minutes'] as num?)?.toInt() ?? 5,
        flapPerHour: (json['flap_per_hour'] as num?)?.toInt() ?? 12,
        mismatchGraceMinutes:
            (json['mismatch_grace_minutes'] as num?)?.toInt() ?? 3,
        cooldownMinutes: (json['cooldown_minutes'] as num?)?.toInt() ?? 30,
      );

  final int debounceSeconds;
  final int staleMinutes;
  final int flapPerHour;
  final int mismatchGraceMinutes;
  final int cooldownMinutes;

  Map<String, dynamic> toRpc() => {
    'p_debounce_seconds': debounceSeconds,
    'p_stale_minutes': staleMinutes,
    'p_flap_per_hour': flapPerHour,
    'p_mismatch_grace_minutes': mismatchGraceMinutes,
    'p_cooldown_minutes': cooldownMinutes,
  };

  @override
  List<Object?> get props => [
    debounceSeconds,
    staleMinutes,
    flapPerHour,
    mismatchGraceMinutes,
    cooldownMinutes,
  ];
}
