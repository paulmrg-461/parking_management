import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/emergency/presentation/emergency_action.dart';
import 'package:parking_management/features/emergency/presentation/emergency_dialog.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';

import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: a configured quadrant shows the number and calls it', (
    tester,
  ) async {
    String? called;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: EmergencyDialog(
            policePhone: '+57 300 111 2233',
            siteName: 'Parqueadero Central',
            siteAddress: 'Cra 7 # 12-34',
            onCall: (phone) async {
              called = phone;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergencia'), findsOneWidget);
    expect(find.text('+57 300 111 2233'), findsOneWidget);
    expect(
      find.text('Ubicación: Parqueadero Central\nCra 7 # 12-34'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('emergency_configure')), findsNothing);

    await tester.tap(find.byKey(const Key('emergency_call')));
    await tester.pumpAndSettle();

    expect(called, '+573001112233');
  });

  testWidgets('Empty: without a quadrant it falls back to 123', (tester) async {
    String? called;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: EmergencyDialog(
            policePhone: '',
            onCall: (phone) async {
              called = phone;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('123'), findsOneWidget);
    expect(find.text('Llamar al 123'), findsOneWidget);
    expect(
      find.text(
        'Pide al administrador que configure el número del cuadrante en Ajustes.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('emergency_call')));
    await tester.pumpAndSettle();

    expect(called, '123');
  });

  testWidgets('Success: an admin can jump to settings when unconfigured', (
    tester,
  ) async {
    var configured = false;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: EmergencyDialog(
            policePhone: '',
            canConfigure: true,
            onConfigure: () => configured = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('emergency_configure')));
    await tester.pumpAndSettle();

    expect(configured, isTrue);
  });

  testWidgets('Success: the appbar action reads the configured quadrant', (
    tester,
  ) async {
    final repository = FakeParkingSettingsRepository(
      const ParkingSettings(
        name: 'Parqueadero Central',
        policePhone: '+57 300 111 2233',
      ),
    );
    final branding = BrandingCubit(repository);
    addTearDown(branding.close);
    await branding.load();

    await tester.pumpWidget(
      testApp(
        BlocProvider<BrandingCubit>.value(
          value: branding,
          child: Scaffold(appBar: AppBar(actions: const [EmergencyAction()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Emergencia'));
    await tester.pumpAndSettle();

    expect(find.text('+57 300 111 2233'), findsOneWidget);
    expect(find.text('Llamar ahora'), findsOneWidget);
  });
}
