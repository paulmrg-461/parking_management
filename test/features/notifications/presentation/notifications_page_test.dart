import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/notifications/application/notifications_cubit.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';
import 'package:parking_management/features/notifications/presentation/notification_bell.dart';
import 'package:parking_management/features/notifications/presentation/notifications_page.dart';

import '../../../helpers/fake_notification_repository.dart';
import '../../../helpers/test_app.dart';

AppNotification _notification(int id) => AppNotification(
  id: id,
  type: 'check_out',
  title: 'Vehículo ABC$id salió',
  body: 'Salida registrada. Cobro: \$5000',
  createdAt: DateTime.utc(2026, 10, 23, 12, id),
);

void main() {
  testWidgets('Success: lists notifications and marks one read on tap', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      items: [_notification(1), _notification(2)],
    );
    final cubit = NotificationsCubit(repository);
    await cubit.start(1);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(value: cubit, child: const NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Vehículo ABC1 salió'), findsOneWidget);

    await tester.tap(find.text('Vehículo ABC1 salió'));
    await tester.pumpAndSettle();

    expect(repository.markedIds, [1]);
  });

  testWidgets('Failure: empty inbox shows its empty state', (tester) async {
    final repository = FakeNotificationRepository();
    final cubit = NotificationsCubit(repository);
    await cubit.start(1);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(value: cubit, child: const NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay notificaciones'), findsOneWidget);
  });

  testWidgets('Security: the bell exposes the unread count', (tester) async {
    final repository = FakeNotificationRepository(items: [_notification(1)]);
    final cubit = NotificationsCubit(repository);
    await cubit.start(1);
    addTearDown(cubit.close);
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            appBar: AppBar(actions: const [NotificationBell()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });
}
