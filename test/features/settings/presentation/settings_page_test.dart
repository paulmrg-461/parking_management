import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/application/settings_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/settings/presentation/settings_page.dart';

import '../../../helpers/fake_settings_repository.dart';
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
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(repository)),
        BlocProvider<BrandingCubit>.value(
          value: branding ?? BrandingCubit(repository),
        ),
      ],
      child: testApp(SettingsPage(pickLogo: pickLogo)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The form is taller than the viewport: bring the save button on screen.
Future<void> scrollToSave(WidgetTester tester) => tester.scrollUntilVisible(
  find.widgetWithText(FilledButton, 'Guardar'),
  300,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  testWidgets('Success: saves the edited identity and confirms', (tester) async {
    final repository = FakeParkingSettingsRepository(_configured);
    await pumpPage(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('settings_name')),
      'Parqueadero Sur',
    );
    await scrollToSave(tester);
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
    await scrollToSave(tester);
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
}
