import '../entities/app_notification.dart';

abstract class NotificationRepository {
  /// Newest first; falls back to the local cache when offline.
  Future<List<AppNotification>> load({int limit = 100});

  /// Marks [ids] read (all unread when null) and returns the affected count.
  Future<int> markRead({List<int>? ids});

  /// Live inserts for [userId] (Supabase Realtime).
  Stream<AppNotification> watch(int? userId);

  /// Stores the FCM/APNs token for background delivery.
  Future<void> registerDeviceToken(String token, String platform);

  Future<void> unregisterDeviceToken(String token);
}
