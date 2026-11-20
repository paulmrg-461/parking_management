import 'package:equatable/equatable.dart';

import '../entities/barrier.dart';

/// Only the fields the admin changed; null means "leave it as it is".
class BarrierConfigUpdate extends Equatable {
  const BarrierConfigUpdate({
    required this.deviceId,
    this.direction,
    this.cameraDeviceId,
    this.openOnCheckin,
    this.openOnPaidExit,
    this.openForPassEntry,
    this.openHoldMs,
    this.maxOpenSeconds,
    this.postClearDelayMs,
    this.maxReversals,
    this.commandTtlSeconds,
  });

  final int deviceId;
  final BarrierDirection? direction;

  /// `0` clears the pairing.
  final int? cameraDeviceId;
  final String? openOnCheckin;
  final String? openOnPaidExit;
  final bool? openForPassEntry;
  final int? openHoldMs;
  final int? maxOpenSeconds;
  final int? postClearDelayMs;
  final int? maxReversals;
  final int? commandTtlSeconds;

  @override
  List<Object?> get props => [
    deviceId,
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
