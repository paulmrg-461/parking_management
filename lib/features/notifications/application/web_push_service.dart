import '../domain/entities/web_push_subscription.dart';
import '../domain/repositories/web_push_repository.dart';
import '../infrastructure/web_push/web_push_registrar.dart';

/// Browser push (VAPID). In-app notifications never depend on it: they arrive
/// through Realtime; this only adds OS-level notifications when the operator
/// enables them on a browser.
abstract class WebPushService {
  /// Whether this platform can subscribe at all (web + VAPID key configured).
  bool get supported;

  Future<bool> isEnabled();

  /// Registers the service worker, asks for permission and stores the
  /// endpoint. `false` when the browser denies it.
  Future<bool> enable();

  Future<void> disable();
}

class NoopWebPushService implements WebPushService {
  const NoopWebPushService();

  @override
  bool get supported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<bool> enable() async => false;

  @override
  Future<void> disable() async {}
}

class BrowserWebPushService implements WebPushService {
  BrowserWebPushService(this._registrar, this._repository, this._vapidKey);

  final WebPushRegistrar _registrar;
  final WebPushRepository _repository;
  final String _vapidKey;

  @override
  bool get supported => _vapidKey.isNotEmpty;

  @override
  Future<bool> isEnabled() async {
    if (!supported) {
      return false;
    }
    final existing = await _registrar.current();
    if (existing == null) {
      return false;
    }
    // Re-saving keeps the row owned by the user who just signed in, which
    // matters when several operators share one browser.
    await _save(existing);
    return true;
  }

  @override
  Future<bool> enable() async {
    if (!supported) {
      return false;
    }
    final subscription = await _registrar.subscribe(_vapidKey);
    if (subscription == null) {
      return false;
    }
    return _save(subscription);
  }

  @override
  Future<void> disable() async {
    final existing = await _registrar.current();
    await _registrar.unsubscribe();
    if (existing != null) {
      await _repository.remove(existing.endpoint);
    }
  }

  Future<bool> _save(WebPushSubscription subscription) async {
    try {
      await _repository.save(subscription);
      return true;
    } catch (_) {
      return false;
    }
  }
}
