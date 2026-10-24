import 'package:equatable/equatable.dart';

class StorageUsage extends Equatable {
  const StorageUsage({
    required this.bucket,
    required this.objects,
    required this.bytes,
  });

  final String bucket;
  final int objects;
  final int bytes;

  factory StorageUsage.fromJson(Map<String, dynamic> json) => StorageUsage(
    bucket: json['bucket'] as String? ?? '',
    objects: (json['objects'] as num?)?.toInt() ?? 0,
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [bucket, objects, bytes];
}

/// Operational counters behind the admin diagnostics screen
/// (`rpc/diagnostics_snapshot`).
class DiagnosticsSnapshot extends Equatable {
  const DiagnosticsSnapshot({
    required this.migrations,
    required this.lots,
    required this.activeLots,
    required this.openSessions,
    required this.staleSessions24h,
    required this.openShifts12h,
    required this.pendingPassPayments,
    required this.activeReservations,
    required this.pendingPush,
    required this.deadPush,
    required this.unreadNotifications,
    required this.totalNotifications,
    required this.clientErrors24h,
    required this.idempotencyKeys,
    this.whatsappPending = 0,
    this.whatsappFailed = 0,
    this.whatsappSent24h = 0,
    this.lastMigrationAt,
    this.storage = const [],
  });

  final int migrations;
  final DateTime? lastMigrationAt;
  final int lots;
  final int activeLots;
  final int openSessions;
  final int staleSessions24h;
  final int openShifts12h;
  final int pendingPassPayments;
  final int activeReservations;
  final int pendingPush;
  final int deadPush;
  final int unreadNotifications;
  final int totalNotifications;
  final int clientErrors24h;
  final int idempotencyKeys;
  final int whatsappPending;
  final int whatsappFailed;
  final int whatsappSent24h;
  final List<StorageUsage> storage;

  bool get hasWarnings =>
      staleSessions24h > 0 ||
      openShifts12h > 0 ||
      deadPush > 0 ||
      clientErrors24h > 0 ||
      whatsappFailed > 0;

  factory DiagnosticsSnapshot.fromJson(Map<String, dynamic> json) {
    final notifications = Map<String, dynamic>.from(
      json['notifications'] as Map? ?? const {},
    );
    final whatsapp = Map<String, dynamic>.from(
      json['whatsapp'] as Map? ?? const {},
    );
    int count(Object? value) => (value as num?)?.toInt() ?? 0;
    return DiagnosticsSnapshot(
      migrations: count(json['migrations']),
      lastMigrationAt: switch (json['last_migration_at']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      lots: count(json['lots']),
      activeLots: count(json['active_lots']),
      openSessions: count(json['open_sessions']),
      staleSessions24h: count(json['stale_sessions_24h']),
      openShifts12h: count(json['open_shifts_12h']),
      pendingPassPayments: count(json['pending_pass_payments']),
      activeReservations: count(json['active_reservations']),
      pendingPush: count(notifications['pending_push']),
      deadPush: count(notifications['dead_push']),
      unreadNotifications: count(notifications['unread']),
      totalNotifications: count(notifications['total']),
      clientErrors24h: count(json['client_errors_24h']),
      idempotencyKeys: count(json['idempotency_keys']),
      whatsappPending: count(whatsapp['pending']),
      whatsappFailed: count(whatsapp['failed']),
      whatsappSent24h: count(whatsapp['sent_24h']),
      storage: [
        for (final item in (json['storage'] as List<dynamic>? ?? const []))
          StorageUsage.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  @override
  List<Object?> get props => [
    migrations,
    lastMigrationAt,
    lots,
    activeLots,
    openSessions,
    staleSessions24h,
    openShifts12h,
    pendingPassPayments,
    activeReservations,
    pendingPush,
    deadPush,
    unreadNotifications,
    totalNotifications,
    clientErrors24h,
    idempotencyKeys,
    whatsappPending,
    whatsappFailed,
    whatsappSent24h,
    storage,
  ];
}
