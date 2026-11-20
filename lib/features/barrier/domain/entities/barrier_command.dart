import 'package:equatable/equatable.dart';

enum BarrierSource { checkin, paidExit, passRecognised, manual, onlinePayment }

enum BarrierCommandStatus {
  queued,
  delivered,
  executed,
  rejected,
  expired,
  cancelled;

  bool get isTerminal => switch (this) {
    BarrierCommandStatus.executed ||
    BarrierCommandStatus.rejected ||
    BarrierCommandStatus.expired ||
    BarrierCommandStatus.cancelled => true,
    _ => false,
  };

  bool get succeeded => this == BarrierCommandStatus.executed;
}

/// One "open" order: the audit trail and the device queue. The signature is
/// added at delivery and never reaches the client.
class BarrierCommand extends Equatable {
  const BarrierCommand({
    required this.id,
    required this.source,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    this.deviceId,
    this.deviceName = '',
    this.reason,
    this.requestedByName,
    this.ackedAt,
    this.result = const {},
  });

  factory BarrierCommand.fromJson(Map<String, dynamic> json) {
    final status = _status(json['status']);
    if (status == null) {
      throw const FormatException('unknown barrier command status');
    }
    return BarrierCommand(
      id: json['id'] as String? ?? '',
      deviceId: (json['device_id'] as num?)?.toInt(),
      deviceName: json['device_name'] as String? ?? '',
      source: _source(json['source']) ?? BarrierSource.manual,
      status: status,
      reason: json['reason'] as String?,
      requestedByName: json['requested_by_name'] as String?,
      issuedAt:
          DateTime.tryParse(json['issued_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ackedAt: DateTime.tryParse(json['acked_at'] as String? ?? ''),
      result: json['result'] is Map
          ? Map<String, dynamic>.from(json['result'] as Map)
          : const {},
    );
  }

  final String id;
  final int? deviceId;
  final String deviceName;
  final BarrierSource source;
  final BarrierCommandStatus status;
  final String? reason;
  final String? requestedByName;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? ackedAt;
  final Map<String, dynamic> result;

  @override
  List<Object?> get props => [
    id,
    deviceId,
    deviceName,
    source,
    status,
    reason,
    requestedByName,
    issuedAt,
    expiresAt,
    ackedAt,
    result,
  ];
}

BarrierSource? _source(Object? wire) => switch (wire) {
  'checkin' => BarrierSource.checkin,
  'paid_exit' => BarrierSource.paidExit,
  'pass_recognised' => BarrierSource.passRecognised,
  'manual' => BarrierSource.manual,
  'online_payment' => BarrierSource.onlinePayment,
  _ => null,
};

BarrierCommandStatus? _status(Object? wire) => switch (wire) {
  'queued' => BarrierCommandStatus.queued,
  'delivered' => BarrierCommandStatus.delivered,
  'executed' => BarrierCommandStatus.executed,
  'rejected' => BarrierCommandStatus.rejected,
  'expired' => BarrierCommandStatus.expired,
  'cancelled' => BarrierCommandStatus.cancelled,
  _ => null,
};
