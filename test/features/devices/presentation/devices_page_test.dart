import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/features/devices/application/devices_cubit.dart';
import 'package:parking_management/features/devices/presentation/devices_page.dart';

import '../../../helpers/fake_device_repository.dart';
import '../../../helpers/test_app.dart';

Future<DevicesCubit> _pump(
  WidgetTester tester,
  FakeDeviceRepository repository,
) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = DevicesCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<DevicesCubit>.value(
        value: cubit,
        child: const DevicesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('lists the devices', (tester) async {
    await _pump(tester, FakeDeviceRepository());
    expect(find.byKey(const Key('device_1')), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('En línea'), findsOneWidget);
  });

  testWidgets('empty shows the register call to action', (tester) async {
    await _pump(tester, FakeDeviceRepository(devices: []));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byKey(const Key('devices_add')), findsOneWidget);
  });

  testWidgets('register shows the key once', (tester) async {
    final repository = FakeDeviceRepository(devices: []);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('devices_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('device_name')), 'Barrera');
    await tester.tap(find.byKey(const Key('device_save')));
    await tester.pumpAndSettle();
    expect(repository.registerCalls, 1);
    expect(find.byKey(const Key('device_key_dialog')), findsOneWidget);
    expect(find.text('pkd_key'), findsOneWidget);
  });

  testWidgets('failure shows retry', (tester) async {
    await _pump(
      tester,
      FakeDeviceRepository()..loadError = const NetworkFailure('offline'),
    );
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('rotate shows the new key and toggle updates', (tester) async {
    final repository = FakeDeviceRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('device_rotate_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device_key_dialog')), findsOneWidget);
    expect(find.text('pkd_rotated'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('device_toggle_1')));
    await tester.pumpAndSettle();
    expect(repository.updateCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('events opens the history sheet', (tester) async {
    await _pump(tester, FakeDeviceRepository());
    await tester.tap(find.byKey(const Key('device_events_1')));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsWidgets);
    expect(find.text('registered'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation', (tester) async {
    final repository = FakeDeviceRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('device_delete_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
  });
}
