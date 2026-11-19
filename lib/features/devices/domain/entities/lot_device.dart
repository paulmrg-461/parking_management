import 'package:equatable/equatable.dart';

enum DeviceKind {
  camera,
  barrier,
  sensorHub;

  String get wire => switch (this) {
    DeviceKind.camera => 'camera',
    DeviceKind.barrier => 'barrier',
    DeviceKind.sensorHub => 'sensor_hub',
  };

  static DeviceKind parse(String? value) => switch (value) {
    'barrier' => DeviceKind.barrier,
    'sensor_hub' => DeviceKind.sensorHub,
    _ => DeviceKind.camera,
  };
}

enum DeviceStatus {
  online,
  offline,
  neverSeen,
  disabled;

  static DeviceStatus parse(String? value) => switch (value) {
    'online' => DeviceStatus.online,
    'offline' => DeviceStatus.offline,
    'disabled' => DeviceStatus.disabled,
    _ => DeviceStatus.neverSeen,
  };
}

class LotDevice extends Equatable {
  const LotDevice({
    required this.id,
    required this.kind,
    required this.name,
    this.keyPrefix = '',
    this.enabled = true,
    this.status = DeviceStatus.neverSeen,
    this.lastSeenAt,
    this.firmwareVersion,
    this.lastStatus = const {},
    this.ratePerMinute = 120,
    this.keyRotatedAt,
    this.apiKey,
  });

  final int id;
  final DeviceKind kind;
  final String name;
  final String keyPrefix;
  final bool enabled;
  final DeviceStatus status;
  final DateTime? lastSeenAt;
  final String? firmwareVersion;
  final Map<String, dynamic> lastStatus;
  final int ratePerMinute;
  final DateTime? keyRotatedAt;

  /// Only present in the register/rotate answer; shown once.
  final String? apiKey;

  factory LotDevice.fromJson(Map<String, dynamic> json) => LotDevice(
    id: (json['id'] as num?)?.toInt() ?? 0,
    kind: DeviceKind.parse(json['kind'] as String?),
    name: json['name'] as String? ?? '',
    keyPrefix: json['key_prefix'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    status: DeviceStatus.parse(json['status'] as String?),
    lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
    firmwareVersion: json['firmware_version'] as String?,
    lastStatus: json['last_status'] is Map
        ? Map<String, dynamic>.from(json['last_status'] as Map)
        : const {},
    ratePerMinute: (json['rate_per_minute'] as num?)?.toInt() ?? 120,
    keyRotatedAt: DateTime.tryParse(json['key_rotated_at'] as String? ?? ''),
    apiKey: json['api_key'] as String?,
  );

  @override
  List<Object?> get props => [
    id, kind, name, keyPrefix, enabled, status, lastSeenAt, firmwareVersion,
    lastStatus, ratePerMinute, keyRotatedAt, apiKey,
  ];
}

class DeviceEvent extends Equatable {
  const DeviceEvent({
    required this.id,
    this.deviceId,
    this.deviceName = '',
    this.event = '',
    this.actorName,
    this.detail = const {},
    this.createdAt,
  });

  final int id;
  final int? deviceId;
  final String deviceName;
  final String event;
  final String? actorName;
  final Map<String, dynamic> detail;
  final DateTime? createdAt;

  factory DeviceEvent.fromJson(Map<String, dynamic> json) => DeviceEvent(
    id: (json['id'] as num?)?.toInt() ?? 0,
    deviceId: (json['device_id'] as num?)?.toInt(),
    deviceName: json['device_name'] as String? ?? '',
    event: json['event'] as String? ?? '',
    actorName: json['actor_name'] as String?,
    detail: json['detail'] is Map
        ? Map<String, dynamic>.from(json['detail'] as Map)
        : const {},
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );

  @override
  List<Object?> get props => [
    id, deviceId, deviceName, event, actorName, detail, createdAt,
  ];
}
