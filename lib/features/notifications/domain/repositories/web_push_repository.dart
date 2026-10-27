import '../entities/web_push_subscription.dart';

abstract class WebPushRepository {
  Future<void> save(WebPushSubscription subscription);

  Future<void> remove(String endpoint);
}
