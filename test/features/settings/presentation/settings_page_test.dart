import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/application/settings_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/settings/presentation/settings_page.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/domain/repositories/spot_repository.dart';

import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/fake_spot_repository.dart';
import '../../../helpers/test_app.dart';

const _configured = ParkingSettings(
  name: 'Parqueadero Central',
  address: 'Cra 7 # 12-34',
  logoVersion: 1,
);

const _logoBytes = [1, 2, 3];

Future<void> pumpPage(
  WidgetTester tester, {
  required FakeParkingSettingsRepository repository,
  BrandingCubit? branding,
  Future<Uint8List?> Function()? pickLogo,
  SpotRepository? spots,
}) async {
  // Tall viewport: the settings form (logo + 8 fields + save) must fit
  // without fighting ListView's lazy children while tapping.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(repository)),
        BlocProvider<BrandingCubit>.value(
          value: branding ?? BrandingCubit(repository),
        ),
      ],
      child: testApp(SettingsPage(pickLogo: pickLogo, spots: spots)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: saves the edited identity and confirms', (tester) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_name')),
      'Parqueadero Sur',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.settings.name, 'Parqueadero Sur');
    expect(find.text('Configuración guardada'), findsOneWidget);
  });

  testWidgets('Failure: a rejected save keeps the form and shows the error', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured)
      ..saveError = const ValidationFailure('name must not be empty');
    await pumpPage(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('settings_name')), 'Nope');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('name must not be empty'), findsOneWidget);
    expect(find.text('Nope'), findsOneWidget);
  });

  testWidgets('Security: a failed logo upload leaves the branding untouched', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured)
      ..cached = _configured
      ..logoBytes = Uint8List.fromList(_logoBytes)
      ..logoError = const NetworkFailure('offline');
    final branding = BrandingCubit(repository);
    await branding.load();

    await pumpPage(
      tester,
      repository: repository,
      branding: branding,
      pickLogo: () async => Uint8List.fromList(const [9, 9]),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Elegir logo'));
    await tester.pumpAndSettle();

    expect(find.text('No hay conexión con el servidor'), findsOneWidget);
    expect(branding.state.logoOrNull, Uint8List.fromList(_logoBytes));
    expect(repository.logoBytes, Uint8List.fromList(_logoBytes));
  });

  testWidgets('Security: leaving with unsaved edits asks before discarding', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_name')),
      'Parqueadero Sur',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Still on the form with the edit intact and nothing saved.
    expect(find.byKey(const Key('settings_name')), findsOneWidget);
    expect(repository.settings.name, _configured.name);
  });

  testWidgets('Success: the space capacities are saved', (tester) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_car_capacity')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('settings_moto_capacity')),
      '5',
    );
    await tester.enterText(
      find.byKey(const Key('settings_key_capacity')),
      '3',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.settings.carCapacity, 12);
    expect(repository.settings.motoCapacity, 5);
    expect(repository.settings.keyCapacity, 3);
  });

  testWidgets('Success: out-of-service spots are saved', (tester) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_car_capacity')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('settings_car_out_of_service')),
      '2',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.settings.carCapacity, 12);
    expect(repository.settings.carOutOfService, 2);
    expect(find.byKey(const Key('settings_spots_map')), findsOneWidget);
  });

  testWidgets('Failure: out-of-service cannot exceed the capacity', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_car_capacity')),
      '4',
    );
    await tester.enterText(
      find.byKey(const Key('settings_car_out_of_service')),
      '5',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('No puede superar la capacidad configurada'),
      findsOneWidget,
    );
    expect(repository.settings.carOutOfService, 0);
  });

  testWidgets('Success: a drawn map replaces the out-of-service counters', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(
      tester,
      repository: repository,
      spots: FakeSpotRepository(const [
        ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
        ParkingSpot(
          id: 2,
          code: 'A2',
          group: SlotGroup.car,
          row: 0,
          col: 1,
          active: false,
        ),
        ParkingSpot(id: 3, code: 'M1', group: SlotGroup.moto, row: 0, col: 0),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('se controla en el mapa').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const Key('settings_car_out_of_service')),
      findsNothing,
    );
    expect(find.textContaining('1 bahía(s) en mantenimiento'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_car_capacity')),
      findsOneWidget,
    );
  });

  testWidgets('Security: without a map the counters stay editable', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    expect(
      find.byKey(const Key('settings_car_out_of_service')),
      findsWidgets,
    );
  });
}
