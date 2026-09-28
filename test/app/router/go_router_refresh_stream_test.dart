import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/router/go_router_refresh_stream.dart';

void main() {
  test('Success: notifies listeners on every stream event', () async {
    final controller = StreamController<int>();
    final refresh = GoRouterRefreshStream(controller.stream);
    var notifications = 0;
    refresh.addListener(() => notifications++);

    controller.add(1);
    controller.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 2);
    refresh.dispose();
  });

  test('Failure: stream errors do not crash nor notify', () async {
    final controller = StreamController<int>();
    final refresh = GoRouterRefreshStream(controller.stream);
    var notifications = 0;
    refresh.addListener(() => notifications++);

    controller.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 0);
    refresh.dispose();
  });

  test('Security: dispose cancels the subscription (no leaks, no late notify)', () async {
    final controller = StreamController<int>.broadcast();
    final refresh = GoRouterRefreshStream(controller.stream);
    expect(controller.hasListener, isTrue);

    refresh.dispose();

    expect(controller.hasListener, isFalse);
    controller.add(1);
    await Future<void>.delayed(Duration.zero);
  });
}
