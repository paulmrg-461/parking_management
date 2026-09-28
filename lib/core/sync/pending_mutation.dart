import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Which aggregate a queued mutation targets. Persisted as `.name`, which is
/// byte-identical to the legacy string values, so old queues still parse.
enum MutationEntity { vehicle, tariff, category, checkIn, checkOut }

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
  });

  final MutationEntity entityType;
  final MutationOperation operation;

  /// The server-assigned id, or `null` for a `checkIn` `create` mutation.
  final int? entityId;

  /// `jsonEncode`-d payload map; `null` for `delete`.
  final String? payloadJson;
  final DateTime enqueuedAt;
  final int attempts;
  final String? lastError;

  /// Earliest time the next replay may run (exponential backoff).
  final DateTime? nextAttemptAt;

  /// Parked for the operator to resolve; never replayed automatically.
  final bool deadLettered;

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
  PendingMutation withPayload(String payloadJson) => PendingMutation(
    entityType: entityType,
    operation: operation,
    entityId: entityId,
    payloadJson: payloadJson,
    enqueuedAt: enqueuedAt,
    attempts: attempts,
    lastError: lastError,
    nextAttemptAt: nextAttemptAt,
    deadLettered: deadLettered,
  );

  PendingMutation _copy({
    required int attempts,
    required String lastError,
    required DateTime? nextAttemptAt,
    required bool deadLettered,
  }) => PendingMutation(
    entityType: entityType,
    operation: operation,
    entityId: entityId,
    payloadJson: payloadJson,
    enqueuedAt: enqueuedAt,
    attempts: attempts,
    lastError: lastError,
    nextAttemptAt: nextAttemptAt,
    deadLettered: deadLettered,
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
    'deadLettered': deadLettered,
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
        deadLettered: json['deadLettered'] as bool? ?? false,
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
  ];
}
