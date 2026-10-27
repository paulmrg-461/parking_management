import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/notifications/application/notifications_cubit.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';

import '../../../helpers/fake_notification_repository.dart';

AppNotification _notification(
  int id, {
  bool read = false,
  String type = 'check_in',
}) => AppNotification(
  id: id,
  type: type,
  title: 'Vehículo ABC$id ingresó',
  body: 'Entrada registrada',
  createdAt: DateTime.utc(2026, 10, 23, 12, id),
  isRead: read,
);

void main() {
  test('Success: loads items and counts unread ones', () async {
    final repository = FakeNotificationRepository(
      items: [_notification(1), _notification(2, read: true)],
    );
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);

    await cubit.start(1);

    expect(cubit.state.status, NotificationsStatus.loaded);
    expect(cubit.state.items, hasLength(2));
    expect(cubit.state.unreadCount, 1);
  });

  test('Success: a realtime insert is prepended and exposed as latest', () async {
    final repository = FakeNotificationRepository(items: [_notification(1)]);
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await cubit.start(1);

    repository.incoming.add(_notification(2));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items.first.id, 2);
    expect(cubit.state.latestArrived?.id, 2);
    expect(cubit.state.unreadCount, 2);
  });

  test('Failure: marking read reverts on a network error', () async {
    final repository = _FailingMarkRepository(items: [_notification(1)]);
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await cubit.start(1);

    await cubit.markRead(1);

    expect(cubit.state.items.first.isRead, isFalse);
    expect(cubit.state.actionError, isA<NetworkFailure>());
  });

  test('Success: markAllRead clears the unread count', () async {
    final repository = FakeNotificationRepository(
      items: [_notification(1), _notification(2)],
    );
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await cubit.start(1);

    await cubit.markAllRead();

    expect(cubit.state.unreadCount, 0);
    expect(repository.markedIds, isEmpty);
  });

  test('Security: a duplicated realtime delivery is ignored', () async {
    final repository = FakeNotificationRepository(items: [_notification(1)]);
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await cubit.start(1);

    repository.incoming.add(_notification(1));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items, hasLength(1));
  });

  test('Failure: a load error surfaces as a retryable failure', () async {
    final repository = FakeNotificationRepository(
      loadError: const NetworkFailure('offline'),
    );
    final cubit = NotificationsCubit(repository);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);

    await cubit.start(1);

    expect(cubit.state.status, NotificationsStatus.failure);
    expect(cubit.state.error, isA<NetworkFailure>());
  });
}

class _FailingMarkRepository extends FakeNotificationRepository {
  _FailingMarkRepository({super.items});

  @override
  Future<int> markRead({List<int>? ids}) async =>
      throw const NetworkFailure('offline');
}
