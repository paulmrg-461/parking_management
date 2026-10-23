import 'dart:async';

import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';
import 'package:parking_management/features/notifications/domain/repositories/notification_repository.dart';

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({this.items = const [], this.loadError});

  List<AppNotification> items;
  Failure? loadError;
  final List<int?> markedIds = [];
  final StreamController<AppNotification> incoming =
      StreamController<AppNotification>.broadcast();

  @override
  Future<List<AppNotification>> load({int limit = 100}) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return items;
  }

  @override
  Future<int> markRead({List<int>? ids}) async {
    markedIds.addAll(ids ?? const []);
    if (ids == null) {
      items = [for (final item in items) item.copyWith(isRead: true)];
      return items.length;
    }
    var changed = 0;
    final next = <AppNotification>[];
    for (final item in items) {
      if (ids.contains(item.id) && !item.isRead) {
        changed++;
        next.add(item.copyWith(isRead: true));
      } else {
        next.add(item);
      }
    }
    items = next;
    return changed;
  }

  @override
  Stream<AppNotification> watch(int? userId) => incoming.stream;

  @override
  Future<void> registerDeviceToken(String token, String platform) async {}

  @override
  Future<void> unregisterDeviceToken(String token) async {}

  Future<void> dispose() => incoming.close();
}
