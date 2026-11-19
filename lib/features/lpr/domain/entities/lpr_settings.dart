import 'package:equatable/equatable.dart';

import '../../../devices/domain/entities/lot_device.dart';

enum LprMode { assist, auto }

class LprCamera extends Equatable {
  const LprCamera({
    required this.deviceId,
    required this.name,
    required this.status,
    this.direction,
  });

  factory LprCamera.fromJson(Map<String, dynamic> json) => LprCamera(
    deviceId: (json['device_id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    direction: json['direction'] as String?,
    status: DeviceStatus.parse(json['status'] as String?),
  );

  final int deviceId;
  final String name;
  final String? direction;
  final DeviceStatus status;

  @override
  List<Object?> get props => [deviceId, name, direction, status];
}

/// Per-lot plate-camera configuration. The server is the source of truth:
/// saving sends only the changed fields and the RPC answers with the stored
/// settings.
class LprSettings extends Equatable {
  const LprSettings({
    required this.mode,
    required this.minConfidence,
    required this.autoConfidence,
    required this.minVotes,
    required this.voteWindowSeconds,
    required this.cooldownSeconds,
    required this.cameras,
    this.defaultCategoryId,
    this.actingUserId,
  });

  factory LprSettings.fromJson(Map<String, dynamic> json) => LprSettings(
    mode: json['mode'] == 'auto' ? LprMode.auto : LprMode.assist,
    minConfidence: (json['min_confidence'] as num?)?.toDouble() ?? 0.8,
    autoConfidence: (json['auto_confidence'] as num?)?.toDouble() ?? 0.92,
    minVotes: (json['min_votes'] as num?)?.toInt() ?? 3,
    voteWindowSeconds: (json['vote_window_seconds'] as num?)?.toInt() ?? 8,
    cooldownSeconds: (json['cooldown_seconds'] as num?)?.toInt() ?? 120,
    defaultCategoryId: (json['default_category_id'] as num?)?.toInt(),
    actingUserId: (json['acting_user_id'] as num?)?.toInt(),
    cameras: [
      for (final item in (json['cameras'] as List? ?? const []))
        if (item is Map) LprCamera.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  final LprMode mode;
  final double minConfidence;
  final double autoConfidence;
  final int minVotes;
  final int voteWindowSeconds;
  final int cooldownSeconds;
  final int? defaultCategoryId;
  final int? actingUserId;
  final List<LprCamera> cameras;

  bool get isAuto => mode == LprMode.auto;
  bool get hasCameras => cameras.isNotEmpty;

  @override
  List<Object?> get props => [
    mode,
    minConfidence,
    autoConfidence,
    minVotes,
    voteWindowSeconds,
    cooldownSeconds,
    defaultCategoryId,
    actingUserId,
    cameras,
  ];
}
