import '../../domain/entities/web_push_subscription.dart';
import 'web_push_registrar.dart';

class _UnsupportedRegistrar implements WebPushRegistrar {
  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async => null;

  @override
  Future<WebPushSubscription?> current() async => null;

  @override
  Future<void> unsubscribe() async {}
}

WebPushRegistrar createRegistrar() => _UnsupportedRegistrar();
