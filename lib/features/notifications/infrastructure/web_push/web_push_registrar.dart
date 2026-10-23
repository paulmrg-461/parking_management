import '../../domain/entities/web_push_subscription.dart';

/// Browser-side push subscription. The stub (non-web) implementation always
/// reports "unsupported".
abstract class WebPushRegistrar {
  /// Registers the service worker and asks for permission. Returns `null`
  /// when the browser denies it or push is unavailable.
  Future<WebPushSubscription?> subscribe(String vapidPublicKey);

  /// Existing subscription, without prompting (safe at app start).
  Future<WebPushSubscription?> current();

  Future<void> unsubscribe();
}
