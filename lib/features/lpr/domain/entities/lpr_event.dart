import 'package:equatable/equatable.dart';

enum LprEventKind { entry, exit }

enum LprEventStatus { pending, done, blocked, confirmed, dismissed, expired }

enum LprEventReason {
  assistMode,
  lowConfidence,
  unknownPlate,
  noSystemOperator,
  duplicateSession,
  lotFull,
  error,
  blacklisted,
  exitUnpaid,
  exitPaid,
  noOpenSession,
}

/// A plate read the server decided on. The camera never decides: this is the
/// server's event, with the confidence, votes and reason it recorded.
class LprEvent extends Equatable {
  const LprEvent({
    required this.id,
    required this.kind,
    required this.status,
    required this.plate,
    required this.confidence,
    required this.votes,
    required this.hasPass,
    required this.createdAt,
    this.reason,
    this.sessionId,
    this.snapshotPath,
    this.deviceName = '',
  });

  factory LprEvent.fromJson(Map<String, dynamic> json) {
    final status = _status(json['status']);
    if (status == null) {
      throw const FormatException('unknown lpr event status');
    }
    return LprEvent(
      id: (json['id'] as num).toInt(),
      kind: _kind(json['kind']) ?? LprEventKind.entry,
      status: status,
      reason: _reason(json['reason']),
      plate: json['plate'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      sessionId: (json['session_id'] as num?)?.toInt(),
      hasPass: json['has_pass'] as bool? ?? false,
      snapshotPath: json['snapshot_path'] as String?,
      deviceName: json['device_name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int id;
  final LprEventKind kind;
  final LprEventStatus status;
  final LprEventReason? reason;
  final String plate;
  final double confidence;
  final int votes;
  final int? sessionId;
  final bool hasPass;
  final String? snapshotPath;
  final String deviceName;
  final DateTime createdAt;

  bool get isEntry => kind == LprEventKind.entry;
  bool get isPending => status == LprEventStatus.pending;
  bool get isBlocked => status == LprEventStatus.blocked;

  @override
  List<Object?> get props => [
    id,
    kind,
    status,
    reason,
    plate,
    confidence,
    votes,
    sessionId,
    hasPass,
    snapshotPath,
    deviceName,
    createdAt,
  ];
}

LprEventKind? _kind(Object? wire) => switch (wire) {
  'entry' => LprEventKind.entry,
  'exit' => LprEventKind.exit,
  _ => null,
};

LprEventStatus? _status(Object? wire) => switch (wire) {
  'pending' => LprEventStatus.pending,
  'done' => LprEventStatus.done,
  'blocked' => LprEventStatus.blocked,
  'confirmed' => LprEventStatus.confirmed,
  'dismissed' => LprEventStatus.dismissed,
  'expired' => LprEventStatus.expired,
  _ => null,
};

LprEventReason? _reason(Object? wire) => switch (wire) {
  'assist_mode' => LprEventReason.assistMode,
  'low_confidence' => LprEventReason.lowConfidence,
  'unknown_plate' => LprEventReason.unknownPlate,
  'no_system_operator' => LprEventReason.noSystemOperator,
  'duplicate_session' => LprEventReason.duplicateSession,
  'lot_full' => LprEventReason.lotFull,
  'error' => LprEventReason.error,
  'blacklisted' => LprEventReason.blacklisted,
  'exit_unpaid' => LprEventReason.exitUnpaid,
  'exit_paid' => LprEventReason.exitPaid,
  'no_open_session' => LprEventReason.noOpenSession,
  _ => null,
};
