import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/app.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/app/shell/app_sidebar.dart';
import 'package:parking_management/core/storage/key_value_store.dart';
import 'package:parking_management/core/theme/tokens.dart';
import 'package:parking_management/core/network/connectivity_cubit.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/widgets/sync_badge.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/home/presentation/widgets/dashboard_widgets.dart';
import 'package:parking_management/features/notifications/domain/entities/app_notification.dart';
import 'package:parking_management/core/realtime/local_activity.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_check_out_repository.dart';
import '../../helpers/fake_notification_repository.dart';
import '../../helpers/fake_sync_outbox.dart';

void main() {
  testWidgets('Success: phone width shows a NavigationBar with operator tabs', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Inicio', 'Entrada', 'Salida']) {
      expect(find.widgetWithText(NavigationBar, label), findsOneWidget);
    }
    expect(find.widgetWithText(NavigationBar, 'Más'), findsNothing);
  });

  testWidgets(
    'Success: wide screens show the side navigation with admin sections',
    (tester) async {
      await pumpApp(tester, role: UserRole.admin, size: const Size(1200, 900));

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final sidebar = find.byType(AppSidebar);
      expect(
        find.descendant(of: sidebar, matching: find.text('Usuarios')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sidebar, matching: find.text('Reportes')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sidebar,
          matching: find.text('Operación'.toUpperCase()),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Success: wide home titles the page and keeps the brand aside', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, size: const Size(1200, 900));

    expect(find.widgetWithText(AppBar, 'Inicio'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Parqueadero'),
      ),
      findsOneWidget,
    );
    // Management lives in the sidebar, not duplicated as home shortcuts.
    expect(find.byType(ManagementShortcuts), findsNothing);
    // Signing out lives in the sidebar card on desktop.
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('Success: Gestión is an accordion that remembers its state', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, size: const Size(1200, 900));
    final sidebar = find.byType(AppSidebar);

    expect(
      find.descendant(of: sidebar, matching: find.text('Usuarios')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('sidebar_management_toggle')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sidebar, matching: find.text('Usuarios')),
      findsNothing,
    );
    expect(
      serviceLocator<KeyValueStore>().get(
        'preferences',
        'sidebar_management_open',
      ),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('sidebar_management_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sidebar, matching: find.text('Usuarios')),
      findsOneWidget,
    );
  });

  testWidgets('Success: collapsed sidebar keeps the management icons', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, size: const Size(1400, 900));

    await tester.tap(find.byTooltip('Contraer menú'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sidebar_item_/reports')), findsOneWidget);
    expect(find.byType(AppSidebar), findsOneWidget);
  });

  testWidgets('Success: the sidebar user card signs out on desktop', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, size: const Size(1200, 900));

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('Success: the side navigation collapses and remembers it', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, size: const Size(1400, 900));
    final sidebar = find.byType(AppSidebar);

    expect(tester.getSize(sidebar).width, Layout.sidebar);
    expect(
      find.descendant(of: sidebar, matching: find.text('Usuarios')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Contraer menú'));
    await tester.pumpAndSettle();

    expect(tester.getSize(sidebar).width, Layout.sidebarCollapsed);
    expect(
      find.descendant(of: sidebar, matching: find.text('Usuarios')),
      findsNothing,
    );
    expect(
      serviceLocator<KeyValueStore>().get('preferences', 'sidebar_collapsed'),
      isTrue,
    );
  });

  testWidgets('Success: admin on a phone reaches management via "Más"', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    final usuarios = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Usuarios'),
    );
    // The management sheet has more entries than fit on screen.
    await tester.scrollUntilVisible(
      usuarios,
      200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(usuarios);
    await tester.pumpAndSettle();
    await tester.tap(usuarios);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Failure: content width is capped on wide screens', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator, size: const Size(1600, 900));

    final home = tester.getSize(find.text('Hola, Juan').first);
    expect(home.width, lessThanOrEqualTo(Layout.maxContent));
    final content = tester.getSize(find.byKey(const Key('app-shell-content')));
    expect(content.width, lessThanOrEqualTo(Layout.maxContent));
  });

  testWidgets('Security: operator sidebar never lists admin sections', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator, size: const Size(1200, 900));
    final sidebar = find.byType(AppSidebar);

    expect(
      find.descendant(of: sidebar, matching: find.text('Salida')),
      findsOneWidget,
    );
    for (final label in ['Usuarios', 'Reportes', 'Tarifas', 'Vehículos']) {
      expect(
        find.descendant(of: sidebar, matching: find.text(label)),
        findsNothing,
      );
    }
  });

  testWidgets('Success: the SyncBadge is visible on sub-pages, not only Home', (
    tester,
  ) async {
    final outbox = FakeSyncOutbox();
    await outbox.enqueue(
      PendingMutation(
        entityType: MutationEntity.vehicle,
        operation: MutationOperation.delete,
        entityId: 1,
        payloadJson: null,
        enqueuedAt: DateTime.utc(2026),
      ),
    );
    await pumpApp(tester, role: UserRole.admin, outbox: outbox);

    expect(find.byType(SyncBadge), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    await goTo(tester, '/users');

    expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('Failure: offline shows the OfflineBanner above the content', (
    tester,
  ) async {
    final connectivity = ConnectivityCubit(_FixedConnectivity(online: false));
    addTearDown(connectivity.close);
    await connectivity.start();

    await pumpApp(tester, role: UserRole.operator, connectivity: connectivity);

    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets('Success: the QR shortcut sits in the shell', (tester) async {
    await pumpApp(tester, role: UserRole.operator);

    expect(find.byTooltip('Escanear QR y registrar salida'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.byIcon(Icons.chat), findsNothing);
  });

  testWidgets('Success: online hides the OfflineBanner', (tester) async {
    final connectivity = ConnectivityCubit(_FixedConnectivity(online: true));
    addTearDown(connectivity.close);
    await connectivity.start();

    await pumpApp(tester, role: UserRole.operator, connectivity: connectivity);

    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('Success: app follows the system theme, Spanish by default', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.locale, const Locale('es'));
    expect(find.byType(ParkingApp), findsOneWidget);
  });

  testWidgets('A11y: dark theme home still meets contrast and targets', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, role: UserRole.operator);

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('Success: another device activity shows a live snackbar', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository();
    await pumpApp(tester, role: UserRole.admin, notifications: notifications);

    notifications.incoming.add(
      AppNotification(
        id: 41,
        type: 'check_in',
        title: 'Entrada registrada',
        body: 'El servidor dice otra cosa',
        createdAt: DateTime.now(),
        data: const {
          'action': 'check_in',
          'session_id': 7,
          'plate': 'ABC123',
          'actor_name': 'Ana',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ana registró el ingreso de ABC123'), findsOneWidget);
  });

  testWidgets('Security: the acting device does not echo its own write', (
    tester,
  ) async {
    LocalActivity.remember('check_in', 7);
    addTearDown(LocalActivity.clear);
    final notifications = FakeNotificationRepository();
    await pumpApp(tester, role: UserRole.admin, notifications: notifications);

    notifications.incoming.add(
      AppNotification(
        id: 42,
        type: 'check_in',
        title: 'Entrada registrada',
        body: 'Ana registró el ingreso de ABC123',
        createdAt: DateTime.now(),
        data: const {
          'action': 'check_in',
          'session_id': 7,
          'plate': 'ABC123',
          'actor_name': 'Ana',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('registró el ingreso de ABC123'), findsNothing);
  });

  testWidgets('Success: an activity refreshes the shell summaries', (
    tester,
  ) async {
    final dashboard = FakeCheckOutRepository();
    final notifications = FakeNotificationRepository();
    await pumpApp(
      tester,
      role: UserRole.admin,
      notifications: notifications,
      dashboardRepository: dashboard,
    );
    final before = dashboard.occupancyCalls;

    notifications.incoming.add(
      AppNotification(
        id: 43,
        type: 'check_in',
        title: 'Entrada registrada',
        body: 'Ana registró el ingreso de ABC123',
        createdAt: DateTime.now(),
        data: const {
          'action': 'check_in',
          'session_id': 8,
          'plate': 'ABC123',
          'actor_name': 'Ana',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(dashboard.occupancyCalls, greaterThan(before));
  });
}

class _FixedConnectivity implements ConnectivityService {
  _FixedConnectivity({required this.online});

  final bool online;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}