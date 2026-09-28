import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app/app.dart';
import 'package:parking_management/core/network/connectivity_cubit.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/widgets/sync_badge.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';

import '../../helpers/app_harness.dart';
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
    'Success: wide screens show a NavigationRail with admin sections',
    (tester) async {
      await pumpApp(tester, role: UserRole.admin, size: const Size(1200, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(NavigationRail, 'Usuarios'), findsOneWidget);
      expect(find.widgetWithText(NavigationRail, 'Reportes'), findsOneWidget);
    },
  );

  testWidgets('Success: admin on a phone reaches management via "Más"', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Usuarios'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Usuarios'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Failure: content width is capped at 840 on wide screens', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator, size: const Size(1600, 900));

    final home = tester.getSize(find.text('Hola, Juan').first);
    expect(home.width, lessThanOrEqualTo(840));
    final content = tester.getSize(find.byKey(const Key('app-shell-content')));
    expect(content.width, lessThanOrEqualTo(840));
  });

  testWidgets('Security: operator rail never lists admin sections', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.operator, size: const Size(1200, 900));

    expect(find.widgetWithText(NavigationRail, 'Salida'), findsOneWidget);
    for (final label in ['Usuarios', 'Reportes', 'Tarifas', 'Vehículos']) {
      expect(find.widgetWithText(NavigationRail, label), findsNothing);
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

    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
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
