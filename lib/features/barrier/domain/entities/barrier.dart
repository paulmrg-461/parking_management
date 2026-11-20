import 'package:equatable/equatable.dart';

import '../../../devices/domain/entities/lot_device.dart';
import 'barrier_command.dart';

enum BarrierDirection { entry, exit }

/// The firmware timings and rules of one barrier. The device enforces the
/// timings it receives inside the signed command; these are the configured
/// values.
class BarrierConfig extends Equatable {
  const BarrierConfig({
    this.direction = BarrierDirection.entry,
    this.cameraDeviceId,
    this.openOnCheckin = 'lpr_only',
    this.openOnPaidExit = 'lpr_only',
    this.openForPassEntry = false,
    this.openHoldMs = 1000,
    this.maxOpenSeconds = 20,
    this.postClearDelayMs = 1500,
    this.maxReversals = 3,
    this.commandTtlSeconds = 30,
  });

  factory BarrierConfig.fromJson(Map<String, dynamic> json) => BarrierConfig(
    direction: json['direction'] == 'exit'
        ? BarrierDirection.exit
        : BarrierDirection.entry,
    cameraDeviceId: (json['camera_device_id'] as num?)?.toInt(),
    openOnCheckin: json['open_on_checkin'] as String? ?? 'lpr_only',
    openOnPaidExit: json['open_on_paid_exit'] as String? ?? 'lpr_only',
    openForPassEntry: json['open_for_pass_entry'] as bool? ?? false,
    openHoldMs: (json['open_hold_ms'] as num?)?.toInt() ?? 1000,
    maxOpenSeconds: (json['max_open_seconds'] as num?)?.toInt() ?? 20,
    postClearDelayMs: (json['post_clear_delay_ms'] as num?)?.toInt() ?? 1500,
    maxReversals: (json['max_reversals'] as num?)?.toInt() ?? 3,
    commandTtlSeconds:
        (json['command_ttl_seconds'] as num?)?.toInt() ?? 30,
  );

  final BarrierDirection direction;
  final int? cameraDeviceId;

  /// `never`, `lpr_only` or `always`.
  final String openOnCheckin;
  final String openOnPaidExit;
  final bool openForPassEntry;
  final int openHoldMs;
  final int maxOpenSeconds;
  final int postClearDelayMs;
  final int maxReversals;
  final int commandTtlSeconds;

  @override
  List<Object?> get props => [
    direction,
    cameraDeviceId,
    openOnCheckin,
    openOnPaidExit,
    openForPassEntry,
    openHoldMs,
    maxOpenSeconds,
    postClearDelayMs,
    maxReversals,
    commandTtlSeconds,
  ];
}

class Barrier extends Equatable {
  const Barrier({
    required this.deviceId,
    required this.name,
    required this.status,
    this.enabled = true,
    this.direction = BarrierDirection.entry,
    this.lastSeenAt,
    this.firmwareVersion,
    this.cameraDeviceId,
    this.cameraName,
    this.config,
    this.inFlight,
    this.lastCommand,
  });

  factory Barrier.fromJson(Map<String, dynamic> json) {
    final configRaw = json['config'];
    final config = configRaw is Map
        ? BarrierConfig.fromJson(Map<String, dynamic>.from(configRaw))
        : null;
    return Barrier(
      deviceId: (json['device_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      status: DeviceStatus.parse(json['status'] as String?),
      direction: config?.direction ??
          (json['direction'] == 'exit'
              ? BarrierDirection.exit
              : BarrierDirection.entry),
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      firmwareVersion: json['firmware_version'] as String?,
      cameraDeviceId: (json['camera_device_id'] as num?)?.toInt() ??
          config?.cameraDeviceId,
      cameraName: json['camera_name'] as String?,
      config: config,
      inFlight: _command(json['in_flight']),
      lastCommand: _command(json['last_command']),
    );
  }

  final int deviceId;
  final String name;
  final bool enabled;
  final DeviceStatus status;
  final BarrierDirection direction;
  final DateTime? lastSeenAt;
  final String? firmwareVersion;
  final int? cameraDeviceId;
  final String? cameraName;
  final BarrierConfig? config;
  final BarrierCommand? inFlight;
  final BarrierCommand? lastCommand;

  bool get online => status == DeviceStatus.online;
  bool get busy => inFlight != null;

  @override
  List<Object?> get props => [
    deviceId,
    name,
    enabled,
    status,
    direction,
    lastSeenAt,
    firmwareVersion,
    cameraDeviceId,
    cameraName,
    config,
    inFlight,
    lastCommand,
  ];
}

BarrierCommand? _command(Object? raw) {
  if (raw is! Map) return null;
  try {
    return BarrierCommand.fromJson(Map<String, dynamic>.from(raw));
  } on FormatException {
    return null;
  }
}
