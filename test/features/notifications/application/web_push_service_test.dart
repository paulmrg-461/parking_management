import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/notifications/application/web_push_service.dart';
import 'package:parking_management/features/notifications/domain/entities/web_push_subscription.dart';
import 'package:parking_management/features/notifications/domain/repositories/web_push_repository.dart';
import 'package:parking_management/features/notifications/infrastructure/web_push/web_push_registrar.dart';

const _subscription = WebPushSubscription(
  endpoint: 'https://push.example/abc',
  p256dh: 'key',
  auth: 'secret',
);

class _FakeRegistrar implements WebPushRegistrar {
  _FakeRegistrar({this.granted = true, this.existing});

  bool granted;
  WebPushSubscription? existing;
  int unsubscribes = 0;

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async =>
      granted ? _subscription : null;

  @override
  Future<WebPushSubscription?> current() async => existing;

  @override
  Future<void> unsubscribe() async {
    unsubscribes++;
    existing = null;
  }
}

class _FakeRepository implements WebPushRepository {
  final List<String> saved = [];
  final List<String> removed = [];
  bool failing = false;

  @override
  Future<void> save(WebPushSubscription subscription) async {
    if (failing) {
      throw Exception('offline');
    }
    if (!saved.contains(subscription.endpoint)) {
      saved.add(subscription.endpoint);
    }
  }

  @override
  Future<void> remove(String endpoint) async {
    removed.add(endpoint);
  }
}

void main() {
  test('Success: enabling subscribes and stores the endpoint', () async {
    final repository = _FakeRepository();
    final service = BrowserWebPushService(
      _FakeRegistrar(),
      repository,
      'BPublicKey',
    );

    expect(await service.enable(), isTrue);
    expect(repository.saved, ['https://push.example/abc']);
  });

  test('Failure: a denied permission enables nothing', () async {
    final repository = _FakeRepository();
    final service = BrowserWebPushService(
      _FakeRegistrar(granted: false),
      repository,
      'BPublicKey',
    );

    expect(await service.enable(), isFalse);
    expect(repository.saved, isEmpty);
  });

  test('Security: without a VAPID key the service stays inert', () async {
    final repository = _FakeRepository();
    final service = BrowserWebPushService(
      _FakeRegistrar(),
      repository,
      '',
    );

    expect(service.supported, isFalse);
    expect(await service.enable(), isFalse);
    expect(await service.isEnabled(), isFalse);
    expect(repository.saved, isEmpty);
    expect(repository.removed, isEmpty);
  });

  test('Success: an existing subscription re-binds to the signed-in user',
      () async {
    final repository = _FakeRepository();
    final service = BrowserWebPushService(
      _FakeRegistrar(existing: _subscription),
      repository,
      'BPublicKey',
    );

    expect(await service.isEnabled(), isTrue);
    expect(repository.saved, ['https://push.example/abc']);
  });

  test('Success: disabling unsubscribes and drops the stored endpoint',
      () async {
    final registrar = _FakeRegistrar(existing: _subscription);
    final repository = _FakeRepository();
    final service = BrowserWebPushService(registrar, repository, 'BPublicKey');

    await service.disable();

    expect(registrar.unsubscribes, 1);
    expect(repository.removed, ['https://push.example/abc']);
  });

  test('Failure: a storage error is reported, not thrown', () async {
    final repository = _FakeRepository()..failing = true;
    final service = BrowserWebPushService(
      _FakeRegistrar(),
      repository,
      'BPublicKey',
    );

    expect(await service.enable(), isFalse);
  });
}
