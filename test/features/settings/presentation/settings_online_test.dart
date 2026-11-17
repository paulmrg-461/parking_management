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
  tester.view.physicalSize = const Size(800, 2600);
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
  testWidgets('Success: the online section saves window and minimum', (
    tester,
  ) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(name: 'Parqueadero Central'),
    );
    await _pump(tester, repo);

    await tester.ensureVisible(find.byKey(const Key('settings_online_enabled')));
    await tester.tap(find.byKey(const Key('settings_online_enabled')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings_online_grace')), '30');
    await tester.enterText(
      find.byKey(const Key('settings_online_min_amount')),
      '2.000',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repo.settings.onlinePaymentsEnabled, isTrue);
    expect(repo.settings.onlinePaymentGraceMinutes, 30);
    expect(repo.settings.onlinePaymentMinAmount, 2000);
  });

  testWidgets('Failure: a window out of 5..120 blocks the save', (
    tester,
  ) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(
        name: 'Parqueadero Central',
        onlinePaymentsEnabled: true,
      ),
    );
    await _pump(tester, repo);

    await tester.enterText(find.byKey(const Key('settings_online_grace')), '4');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un valor mayor a 0'), findsOneWidget);
    expect(repo.settings.onlinePaymentGraceMinutes, 15);
  });

  testWidgets('Security: a USD site cannot enable online payments', (
    tester,
  ) async {
    final repo = FakeParkingSettingsRepository(
      const ParkingSettings(name: 'Parking US', currency: 'USD'),
    );
    await _pump(tester, repo);

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_online_enabled')),
    );
    expect(tile.onChanged, isNull);
    expect(find.text('Solo disponible para sedes en COP'), findsOneWidget);
  });

  test('Failure: the DTO defaults the online fields on an old payload', () {
    final dto = ParkingSettingsDto.fromJson({
      'name': 'Viejo',
      'address': '',
      'schedule': '',
      'phone': '',
      'website': '',
      'whatsapp': '',
    });
    expect(dto.onlinePaymentsEnabled, isFalse);
    expect(dto.onlinePaymentGraceMinutes, 15);
    expect(dto.onlinePaymentMinAmount, 1500);
  });

  test('Success: the DTO maps the online snake_case columns', () {
    final dto = ParkingSettingsDto.fromJson({
      'name': 'Nuevo',
      'address': '',
      'schedule': '',
      'phone': '',
      'website': '',
      'whatsapp': '',
      'online_payments_enabled': true,
      'online_payment_grace_minutes': 30,
      'online_payment_min_amount': 2000,
    });
    final settings = dto.toDomain();
    expect(settings.onlinePaymentsEnabled, isTrue);
    expect(settings.onlinePaymentGraceMinutes, 30);
    expect(settings.onlinePaymentMinAmount, 2000);
    expect(settings.toPayload()['online_payment_min_amount'], 2000);
  });
}
