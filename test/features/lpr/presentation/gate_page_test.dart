import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/lpr/application/lpr_inbox_cubit.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_event.dart';
import 'package:parking_management/features/lpr/presentation/gate_page.dart';

import '../../../helpers/fake_lpr_repository.dart';
import '../../../helpers/test_app.dart';

Widget gate(FakeLprRepository repository, {Future<bool> Function()? online}) {
  return testApp(
    BlocProvider(
      create: (_) => LprInboxCubit(repository),
      child: GatePage(online: online ?? () async => true),
    ),
  );
}

void main() {
  testWidgets('shows the pending card with plate and reason', (tester) async {
    await tester.pumpWidget(gate(FakeLprRepository()));
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Modo asistido'), findsOneWidget);
    expect(find.byKey(const Key('lpr_confirm_1')), findsOneWidget);
  });

  testWidgets('empty state offers the check-in call to action', (tester) async {
    await tester.pumpWidget(gate(FakeLprRepository()..events = []));
    await tester.pumpAndSettle();
    expect(find.text('No hay placas por revisar'), findsOneWidget);
    expect(find.text('Registrar entrada'), findsOneWidget);
  });

  testWidgets('error state retries the load', (tester) async {
    final repository = FakeLprRepository()
      ..listError = const NetworkFailure('offline');
    await tester.pumpWidget(gate(repository));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repository.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('confirming opens the dialog and sends the edited plate',
      (tester) async {
    final repository = FakeLprRepository();
    await tester.pumpWidget(gate(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpr_confirm_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpr_confirm_dialog')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'XYZ987');
    await tester.tap(find.byKey(const Key('lpr_confirm_submit')));
    await tester.pumpAndSettle();
    expect(repository.confirmed.single.plate, 'XYZ987');
    expect(find.text('Entrada confirmada'), findsOneWidget);
  });

  testWidgets('confirming offline shows the message and opens no dialog',
      (tester) async {
    final repository = FakeLprRepository();
    await tester.pumpWidget(gate(repository, online: () async => false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpr_confirm_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpr_confirm_dialog')), findsNothing);
    expect(find.text('Confirmar requiere conexión'), findsOneWidget);
    expect(repository.confirmed, isEmpty);
  });

  testWidgets('dismiss removes the card', (tester) async {
    final repository = FakeLprRepository();
    await tester.pumpWidget(gate(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpr_dismiss_1')));
    await tester.pumpAndSettle();
    expect(repository.dismissed, [1]);
    expect(find.text('Lectura descartada'), findsOneWidget);
  });

  testWidgets('an unpaid exit opens the check-out with the plate',
      (tester) async {
    final repository = FakeLprRepository()
      ..events = [
        fakeLprEvent(
          id: 2,
          kind: LprEventKind.exit,
          reason: LprEventReason.exitUnpaid,
          sessionId: 40,
        ),
      ];
    final router = GoRouter(
      initialLocation: '/gate',
      routes: [
        GoRoute(
          path: '/gate',
          builder: (_, _) => BlocProvider(
            create: (_) => LprInboxCubit(repository),
            child: const GatePage(),
          ),
        ),
        GoRoute(
          path: '/check-out',
          builder: (_, state) => Scaffold(
            body: Text('checkout ${state.uri.queryParameters['scan']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(testRouterApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lpr_checkout_2')));
    await tester.pumpAndSettle();
    expect(find.text('checkout ABC123'), findsOneWidget);
  });

  testWidgets('a read with a snapshot shows its thumbnail', (tester) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
      'hQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final repository = FakeLprRepository()
      ..events = [fakeLprEvent(id: 3, snapshotPath: 'lpr/1/7/3.jpg')];
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => LprInboxCubit(repository),
          child: GatePage(
            online: () async => true,
            snapshotLoader: (path) async {
              expect(path, 'lpr/1/7/3.jpg');
              return png;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpr_snapshot_image')), findsOneWidget);
  });

  testWidgets('a snapshot error shows the placeholder', (tester) async {
    final repository = FakeLprRepository()
      ..events = [fakeLprEvent(id: 3, snapshotPath: 'lpr/1/7/3.jpg')];
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => LprInboxCubit(repository),
          child: GatePage(
            online: () async => true,
            snapshotLoader: (path) async => throw Exception('denied'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpr_snapshot_missing')), findsOneWidget);
  });

  testWidgets('no snapshot path renders no image', (tester) async {
    await tester.pumpWidget(
      gate(FakeLprRepository()..events = [fakeLprEvent(id: 3)]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lpr_snapshot_image')), findsNothing);
    expect(find.byKey(const Key('lpr_snapshot_missing')), findsNothing);
  });

  testWidgets('an admin sees the settings action and it fires', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => LprInboxCubit(FakeLprRepository()),
          child: GatePage(
            online: () async => true,
            onSettings: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gate_settings_action')));
    expect(opened, isTrue);
  });

  testWidgets('meets the tap-target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(gate(FakeLprRepository()));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
