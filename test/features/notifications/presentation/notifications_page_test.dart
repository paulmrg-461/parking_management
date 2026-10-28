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

    expect(find.text('Bandeja vacía'), findsOneWidget);
    expect(
      find.text(
        'Los avisos de entradas, salidas, turnos y mensualidades aparecerán aquí.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ver registros'), findsOneWidget);
  });

  testWidgets('Success: the unread filter hides read notifications', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      items: [
        _notification(1),
        AppNotification(
          id: 2,
          type: 'check_in',
          title: 'Vehículo XYZ2 entró',
          body: 'Ingreso registrado',
          createdAt: DateTime.now(),
          isRead: true,
        ),
      ],
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

    expect(find.text('Vehículo XYZ2 entró'), findsOneWidget);

    await tester.tap(find.text('No leídas'));
    await tester.pumpAndSettle();

    expect(find.text('Vehículo XYZ2 entró'), findsNothing);
    expect(find.text('Vehículo ABC1 salió'), findsOneWidget);
  });

  testWidgets('Success: notifications are grouped by day', (tester) async {
    final repository = FakeNotificationRepository(
      items: [
        AppNotification(
          id: 3,
          type: 'check_in',
          title: 'Vehículo HOY3 entró',
          body: 'Ingreso registrado',
          createdAt: DateTime.now(),
        ),
        _notification(1),
      ],
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

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Anteriores'), findsOneWidget);
  });

  testWidgets('A11y: inbox rows and filters meet touch and contrast', (
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

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
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
