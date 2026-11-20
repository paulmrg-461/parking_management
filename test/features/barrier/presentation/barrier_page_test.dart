import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/barrier/application/barrier_cubit.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier_command.dart';
import 'package:parking_management/features/barrier/presentation/barrier_page.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';

import '../../../helpers/fake_barrier_repository.dart';
import '../../../helpers/test_app.dart';

Widget page(FakeBarrierRepository repository, {bool isAdmin = false}) => testApp(
  BlocProvider(
    create: (_) => BarrierCubit(repository),
    child: BarrierPage(isAdmin: isAdmin),
  ),
);

void main() {
  testWidgets('shows the barrier, its direction and an enabled open button',
      (tester) async {
    await tester.pumpWidget(page(FakeBarrierRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Salida'), findsWidgets);
    expect(find.text('Salida'), findsWidgets);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('barrier_open_1')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('an offline barrier disables the open button', (tester) async {
    await tester.pumpWidget(
      page(FakeBarrierRepository()..barriers = [
        fakeBarrier(status: DeviceStatus.offline),
      ]),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('barrier_open_1')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Sin conexión: usa la llave o el control de la barrera'),
      findsOneWidget,
    );
  });

  testWidgets('opening asks for a reason, sends it and shows the result',
      (tester) async {
    final repository = FakeBarrierRepository()
      ..pollStatuses = const [BarrierCommandStatus.executed];
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('barrier_open_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barrier_open_dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('barrier_reason')),
      'Cliente sin ticket',
    );
    await tester.tap(find.byKey(const Key('barrier_open_confirm')));
    await tester.pumpAndSettle();
    expect(repository.opened.single.reason, 'Cliente sin ticket');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Barrera abierta'), findsOneWidget);
  });

  testWidgets('a short reason keeps the dialog open', (tester) async {
    final repository = FakeBarrierRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('barrier_open_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('barrier_reason')), 'x');
    await tester.tap(find.byKey(const Key('barrier_open_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barrier_open_dialog')), findsOneWidget);
    expect(
      find.text('Escribe un motivo de 3 a 200 caracteres'),
      findsOneWidget,
    );
    expect(repository.opened, isEmpty);
  });

  testWidgets('no barriers shows the devices call to action', (tester) async {
    await tester.pumpWidget(page(FakeBarrierRepository()..barriers = []));
    await tester.pumpAndSettle();
    expect(find.text('No hay barreras registradas'), findsOneWidget);
    expect(find.text('Ir a Dispositivos'), findsOneWidget);
  });

  testWidgets('a load failure offers retry and recovers', (tester) async {
    final repository = FakeBarrierRepository()
      ..listError = const NetworkFailure('offline');
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repository.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Salida'), findsWidgets);
  });

  testWidgets('only admins see the configuration action', (tester) async {
    await tester.pumpWidget(page(FakeBarrierRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barrier_config_1')), findsNothing);
    await tester.pumpWidget(page(FakeBarrierRepository(), isAdmin: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barrier_config_1')), findsOneWidget);
  });

  testWidgets('an admin configures the barrier and saves', (tester) async {
    final repository = FakeBarrierRepository();
    await tester.pumpWidget(page(repository, isAdmin: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('barrier_config_1')));
    await tester.pumpAndSettle();
    expect(find.text('Configuración de la barrera'), findsOneWidget);
    await tester.tap(find.byKey(const Key('barrier_config_pass')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('barrier_config_save')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('barrier_config_save')));
    await tester.pumpAndSettle();
    final update = repository.saved.single;
    expect(update.openForPassEntry, isTrue);
    expect(update.openHoldMs, 1100);
  });

  testWidgets('the history sheet lists the commands', (tester) async {
    final repository = FakeBarrierRepository()
      ..historyItems = [
        fakeBarrierCommand(source: BarrierSource.paidExit, reason: 'Pago'),
      ];
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('barrier_history_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ana'), findsWidgets);
    expect(find.textContaining('Salida pagada'), findsOneWidget);
    expect(find.textContaining('Pago'), findsOneWidget);
  });

  testWidgets('meets the tap-target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(page(FakeBarrierRepository(), isAdmin: true));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
