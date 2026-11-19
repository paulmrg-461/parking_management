import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Which aggregate a queued mutation targets. Persisted as `.name`, which is
/// byte-identical to the legacy string values, so old queues still parse.
enum MutationEntity { vehicle, tariff, category, checkIn, checkOut, settings }

/// What to do with the entity. Persisted as `.name` (legacy compatible).
enum MutationOperation { create, update, delete, close }

/// A single queued mutation waiting to be replayed against the backend once
/// connectivity is restored: `update`/`delete` for vehicles/tariffs/
/// categories, plus `create` for check-ins and `close` for check-outs.
///
/// Deliberately NOT a Hive-adapter type: it is stored as
/// `jsonEncode(toJson())` inside a `Box<String>` (see `HiveSyncOutbox`).
/// Retry metadata ([attempts], [lastError], [nextAttemptAt],
/// [deadLettered]) is optional in JSON so entries written by older builds
/// load with defaults.
class PendingMutation extends Equatable {
  const PendingMutation({
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.payloadJson,
    required this.enqueuedAt,
    this.attempts = 0,
    this.lastError,
    this.nextAttemptAt,
    this.deadLettered = false,
    this.baseVersion,
    this.baseSnapshotJson,
    this.needsResolution = false,
    this.conflictKind,
    this.serverJson,
  });

  final MutationEntity entityType;
  final MutationOperation operation;

  /// The server-assigned id, or `null` for a `checkIn` `create` mutation and
  /// for `settings` updates (the record is a singleton).
  final int? entityId;

  /// `jsonEncode`-d payload map; `null` for `delete`.
  final String? payloadJson;
  final DateTime enqueuedAt;
  final int attempts;
  final String? lastError;

  /// Earliest time the next replay may run (exponential backoff).
  final DateTime? nextAttemptAt;

  /// An unrecoverable failure: shown, never retried.
  final bool deadLettered;

  /// The row version the edit was based on (`null` for a legacy entry).
  final int? baseVersion;

  /// The cached row (JSON) at the moment of the edit, for the merge.
  final String? baseSnapshotJson;

  /// Parked for the operator: never replayed until they choose.
  final bool needsResolution;

  /// `edited` (someone changed a field we also changed) or `deleted`.
  final String? conflictKind;

  /// The row the server had when the conflict was detected.
  final String? serverJson;

  /// `pending`, `conflict` or `deadLetter` (the only three shapes a queue
  /// entry can have).
  String get state => needsResolution
      ? 'conflict'
      : deadLettered
      ? 'deadLetter'
      : 'pending';

  Map<String, dynamic>? decodeBaseSnapshot() => baseSnapshotJson == null
      ? null
      : jsonDecode(baseSnapshotJson!) as Map<String, dynamic>;

  Map<String, dynamic>? decodeServerRow() => serverJson == null
      ? null
      : jsonDecode(serverJson!) as Map<String, dynamic>;

  /// Parks this entry as a conflict (the operator decides what to keep).
  PendingMutation asConflict({
    required String kind,
    Map<String, dynamic>? serverRow,
  }) => _copy(
    attempts: attempts,
    lastError: lastError,
    nextAttemptAt: null,
    deadLettered: false,
    baseVersion: baseVersion,
    baseSnapshotJson: baseSnapshotJson,
    needsResolution: true,
    conflictKind: kind,
    serverJson: serverRow == null ? null : jsonEncode(serverRow),
  );

  /// Sends the merged fields from a newer base (after an auto-merge or a
  /// "keep mine" choice).
  PendingMutation rebased({
    required int baseVersion,
    required String? payloadJson,
    required String baseSnapshotJson,
  }) => PendingMutation(
    entityType: entityType,
    operation: operation,
    entityId: entityId,
    payloadJson: payloadJson,
    enqueuedAt: enqueuedAt,
    baseVersion: baseVersion,
    baseSnapshotJson: baseSnapshotJson,
  );

  /// The decoded payload map (empty for payload-less mutations).
  Map<String, dynamic> decodePayload() => payloadJson == null
      ? <String, dynamic>{}
      : jsonDecode(payloadJson!) as Map<String, dynamic>;

  /// Returns a copy with one more failed attempt recorded.
  PendingMutation recordFailure(
    String message, {
    DateTime? nextAttemptAt,
    bool deadLettered = false,
  }) => _copy(
    attempts: attempts + 1,
    lastError: message,
    nextAttemptAt: nextAttemptAt,
    deadLettered: deadLettered,
  );

  /// Returns a copy whose payload is replaced by [payloadJson].
  PendingMutation withPayload(String payloadJson) => _copy(
    attempts: attempts,
    lastError: lastError,
    nextAttemptAt: nextAttemptAt,
    deadLettered: deadLettered,
    payloadJson: payloadJson,
  );

  PendingMutation _copy({
    required int attempts,
    required String? lastError,
    required DateTime? nextAttemptAt,
    required bool deadLettered,
    String? payloadJson,
    int? baseVersion,
    bool clearBaseVersion = false,
    String? baseSnapshotJson,
    bool? needsResolution,
    String? conflictKind,
    String? serverJson,
  }) => PendingMutation(
    entityType: entityType,
    operation: operation,
    entityId: entityId,
    payloadJson: payloadJson ?? this.payloadJson,
    enqueuedAt: enqueuedAt,
    attempts: attempts,
    lastError: lastError,
    nextAttemptAt: nextAttemptAt,
    deadLettered: deadLettered,
    baseVersion: clearBaseVersion ? null : (baseVersion ?? this.baseVersion),
    baseSnapshotJson: baseSnapshotJson ?? this.baseSnapshotJson,
    needsResolution: needsResolution ?? this.needsResolution,
    conflictKind: conflictKind ?? this.conflictKind,
    serverJson: serverJson ?? this.serverJson,
  );

  Map<String, dynamic> toJson() => {
    'entityType': entityType.name,
    'operation': operation.name,
    'entityId': entityId,
    'payloadJson': payloadJson,
    'enqueuedAt': enqueuedAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    // An older build ignores the conflict fields; writing `deadLettered` for
    // a parked conflict keeps it from replaying blindly.
    'deadLettered': deadLettered || needsResolution,
    'baseVersion': baseVersion,
    'baseSnapshotJson': baseSnapshotJson,
    'needsResolution': needsResolution,
    'conflictKind': conflictKind,
    'serverJson': serverJson,
  };

  factory PendingMutation.fromJson(Map<String, dynamic> json) =>
      PendingMutation(
        entityType: _parse(MutationEntity.values, json['entityType']),
        operation: _parse(MutationOperation.values, json['operation']),
        entityId: json['entityId'] as int?,
        payloadJson: json['payloadJson'] as String?,
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
        nextAttemptAt: _parseDate(json['nextAttemptAt']),
        // An entry parked as a conflict is not a dead letter, even though its
        // JSON says so for older builds.
        deadLettered:
            (json['deadLettered'] as bool? ?? false) &&
            !(json['needsResolution'] as bool? ?? false),
        baseVersion: json['baseVersion'] as int?,
        baseSnapshotJson: json['baseSnapshotJson'] as String?,
        needsResolution: json['needsResolution'] as bool? ?? false,
        conflictKind: json['conflictKind'] as String?,
        serverJson: json['serverJson'] as String?,
      );

  static T _parse<T extends Enum>(List<T> values, Object? raw) {
    final match = values.asNameMap()[raw];
    if (match == null) {
      throw FormatException('Unknown ${T.toString()} value', raw);
    }
    return match;
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.parse(raw) : null;

  @override
  List<Object?> get props => [
    entityType,
    operation,
    entityId,
    payloadJson,
    enqueuedAt,
    attempts,
    lastError,
    nextAttemptAt,
    deadLettered,
    baseVersion,
    baseSnapshotJson,
    needsResolution,
    conflictKind,
    serverJson,
  ];
}
