import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/application/settings_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/settings/infrastructure/models/parking_settings_dto.dart';
import 'package:parking_management/features/settings/presentation/settings_page.dart';

import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> _pump(WidgetTester tester, FakeParkingSettingsRepository repo) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(repo)),
        BlocProvider<BrandingCubit>.value(value: BrandingCubit(repo)),
      ],
      child: testApp(const SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: saves the renewal switch, links and cadence', (
    tester,
  ) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(
        name: 'Central',
        onlinePaymentsEnabled: true,
      ),
    );
    await _pump(tester, repo);

    await tester.ensureVisible(
      find.byKey(const Key('settings_pass_renewal_enabled')),
    );
    await tester.tap(find.byKey(const Key('settings_pass_renewal_enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_pass_renewal_links')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings_pass_cadence')), '10,5');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repo.settings.passRenewalEnabled, isTrue);
    expect(repo.settings.passRenewalPaymentLinks, isTrue);
    expect(repo.settings.passRenewalCadence, '10,5');
  });

  testWidgets('Failure: a 6-value cadence blocks the save', (tester) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(
        name: 'Central',
        passRenewalEnabled: true,
        passRenewalCadence: '7,3,1',
      ),
    );
    await _pump(tester, repo);

    await tester.enterText(
      find.byKey(const Key('settings_pass_cadence')),
      '7,3,1,5,2,1',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Usa hasta 5 números entre 0 y 30 separados por comas'),
      findsOneWidget,
    );
    expect(repo.settings.passRenewalCadence, '7,3,1');
  });

  testWidgets('Security: the links switch needs online payments', (
    tester,
  ) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(name: 'Central', passRenewalEnabled: true),
    );
    await _pump(tester, repo);

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_pass_renewal_links')),
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('Security: a USD site cannot include links', (tester) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(
        name: 'Parking US',
        currency: 'USD',
        onlinePaymentsEnabled: true,
        passRenewalEnabled: true,
      ),
    );
    await _pump(tester, repo);

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_pass_renewal_links')),
    );
    expect(tile.onChanged, isNull);
  });

  test('Failure: an old payload keeps the renewal defaults', () {
    final dto = ParkingSettingsDto.fromJson({
      'name': 'Viejo',
      'address': '',
      'schedule': '',
      'phone': '',
      'website': '',
      'whatsapp': '',
    });
    expect(dto.passRenewalEnabled, isFalse);
    expect(dto.passRenewalPaymentLinks, isFalse);
    expect(dto.passRenewalCadence, '7,3,1');
  });

  test('Success: the DTO maps the pass renewal columns', () {
    final dto = ParkingSettingsDto.fromJson({
      'name': 'Nuevo',
      'address': '',
      'schedule': '',
      'phone': '',
      'website': '',
      'whatsapp': '',
      'pass_renewal_enabled': true,
      'pass_renewal_payment_links': true,
      'pass_renewal_cadence': '10,5',
    });
    final settings = dto.toDomain();
    expect(settings.passRenewalEnabled, isTrue);
    expect(settings.passRenewalPaymentLinks, isTrue);
    expect(settings.passRenewalCadence, '10,5');
    expect(settings.toPayload()['pass_renewal_enabled'], isTrue);
  });
}
