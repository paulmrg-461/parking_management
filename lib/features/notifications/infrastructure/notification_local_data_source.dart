import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/app_notification.dart';

abstract class NotificationLocalDataSource {
  Future<List<AppNotification>> read();

  Future<void> write(List<AppNotification> notifications);
}

/// Last-seen notifications only: the inbox is read-mostly reference data, so
/// a compact JSON list is enough (no Hive adapter/codegen needed).
class HiveNotificationLocalDataSource implements NotificationLocalDataSource {
  static const _boxName = 'notifications';
  static const _key = 'cache';
  static const _maxItems = 100;

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  @override
  Future<List<AppNotification>> read() async {
    final raw = (await _box()).get(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in decoded)
        AppNotification.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> write(List<AppNotification> notifications) async {
    final capped = notifications.take(_maxItems).toList();
    await (await _box()).put(
      _key,
      jsonEncode([for (final notification in capped) notification.toJson()]),
    );
  }
}
