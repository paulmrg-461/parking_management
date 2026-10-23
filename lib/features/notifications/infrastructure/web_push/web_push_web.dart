import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../domain/entities/web_push_subscription.dart';
import 'web_push_registrar.dart';

/// Browser implementation: registers `push-sw.js`, requests permission and
/// reuses the existing subscription when there is one. Payload encryption and
/// delivery live in `push-dispatch`; the client only forwards the endpoint and
/// the two keys.
class BrowserWebPushRegistrar implements WebPushRegistrar {
  static const _workerPath = 'push-sw.js';
  static const _timeout = Duration(seconds: 15);

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) {
      return null;
    }
    try {
      final permission = await web.Notification.requestPermission().toDart;
      if (permission.toDart != 'granted') {
        return null;
      }
      final registration = await _registration();
      final manager = registration.pushManager;
      final existing = await manager.getSubscription().toDart;
      final subscription =
          existing ??
          await manager
              .subscribe(
                web.PushSubscriptionOptionsInit(
                  userVisibleOnly: true,
                  applicationServerKey: _decodeKey(vapidPublicKey).toJS,
                ),
              )
              .toDart;
      return _toSubscription(subscription);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<WebPushSubscription?> current() async {
    try {
      final registration = await _registration();
      final subscription = await registration.pushManager.getSubscription().toDart;
      return subscription == null ? null : _toSubscription(subscription);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> unsubscribe() async {
    try {
      final registration = await _registration();
      final subscription = await registration.pushManager.getSubscription().toDart;
      await subscription?.unsubscribe().toDart;
    } catch (_) {
      // Nothing to release: the endpoint is dropped server-side anyway.
    }
  }

  Future<web.ServiceWorkerRegistration> _registration() async {
    final container = web.window.navigator.serviceWorker;
    await container.register(_workerPath.toJS).toDart;
    return await container.ready.toDart.timeout(_timeout);
  }

  WebPushSubscription? _toSubscription(web.PushSubscription subscription) {
    final p256dh = subscription.getKey('p256dh');
    final auth = subscription.getKey('auth');
    if (p256dh == null || auth == null) {
      return null;
    }
    return WebPushSubscription(
      endpoint: subscription.endpoint,
      p256dh: _encodeKey(p256dh),
      auth: _encodeKey(auth),
    );
  }

  /// VAPID public keys travel as unpadded base64url.
  Uint8List _decodeKey(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + (4 - normalized.length % 4) % 4,
      '=',
    );
    return base64.decode(padded);
  }

  String _encodeKey(JSArrayBuffer buffer) =>
      base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
}

WebPushRegistrar createRegistrar() => BrowserWebPushRegistrar();
