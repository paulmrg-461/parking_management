/// A single queued `update`/`delete` mutation waiting to be replayed against
/// the backend once connectivity is restored.
///
/// Deliberately NOT a Hive-adapter type (no `@GenerateAdapters` entry, no
/// typeId): it is stored as `jsonEncode(toJson())` inside a `Box<String>`
/// (see `HiveSyncOutbox`), which keeps this purely-internal queue record out
/// of the generated-adapter pipeline entirely.
class PendingMutation {
  const PendingMutation({
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.payloadJson,
    required this.enqueuedAt,
  });

  /// `'vehicle' | 'tariff' | 'category'`.
  final String entityType;

  /// `'update' | 'delete'`.
  final String operation;

  final int entityId;

  /// `jsonEncode`-d payload map for `update`; `null` for `delete`.
  final String? payloadJson;

  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'operation': operation,
        'entityId': entityId,
        'payloadJson': payloadJson,
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };

  factory PendingMutation.fromJson(Map<String, dynamic> json) =>
      PendingMutation(
        entityType: json['entityType'] as String,
        operation: json['operation'] as String,
        entityId: json['entityId'] as int,
        payloadJson: json['payloadJson'] as String?,
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );
}
