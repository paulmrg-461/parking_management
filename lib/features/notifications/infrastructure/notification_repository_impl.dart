import '../../../core/error/failure.dart';
import '../domain/entities/app_notification.dart';
import '../domain/repositories/notification_repository.dart';
import 'notification_local_data_source.dart';
import 'notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote, this._local);

  final NotificationRemoteDataSource _remote;
  final NotificationLocalDataSource _local;

  @override
  Future<List<AppNotification>> load({int limit = 100}) async {
    try {
      final notifications = await _remote.list(limit: limit);
      await _local.write(notifications);
      return notifications;
    } on NetworkFailure {
      return _local.read();
    }
  }

  @override
  Future<int> markRead({List<int>? ids}) => _remote.markRead(ids: ids);

  @override
  Stream<AppNotification> watch(int? userId) => _remote.watch(userId);

  @override
  Future<void> registerDeviceToken(String token, String platform) =>
      _remote.registerDeviceToken(token, platform);

  @override
  Future<void> unregisterDeviceToken(String token) =>
      _remote.unregisterDeviceToken(token);
}
