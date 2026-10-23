import 'package:equatable/equatable.dart';

class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.createdAt,
    this.actor,
    this.entityId,
    this.lot,
    this.before,
    this.after,
  });

  final int id;

  /// `insert`, `update` or `delete`.
  final String action;
  final String tableName;
  final DateTime createdAt;
  final String? actor;
  final String? entityId;
  final String? lot;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  Map<String, dynamic> get changes => {...?before, ...?after};

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: (json['id'] as num).toInt(),
    action: json['action'] as String? ?? 'update',
    tableName: json['table_name'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    actor: json['actor'] as String?,
    entityId: json['entity_id'] as String?,
    lot: json['lot'] as String?,
    before: json['before'] is Map
        ? Map<String, dynamic>.from(json['before'] as Map)
        : null,
    after: json['after'] is Map
        ? Map<String, dynamic>.from(json['after'] as Map)
        : null,
  );

  @override
  List<Object?> get props =>
      [id, action, tableName, createdAt, actor, entityId, lot, before, after];
}
