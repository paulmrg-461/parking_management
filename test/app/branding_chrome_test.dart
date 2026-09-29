import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_settings_repository.dart';

Uint8List _png() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwG'
  'A60e6kgAAAABJRU5ErkJggg==',
);

BrandingCubit _branded() => BrandingCubit(
  FakeParkingSettingsRepository(
    const ParkingSettings(
      name: 'Parqueadero Central',
      address: 'Cra 7 # 12-34',
      phone: '+57 300 111 2233',
      logoVersion: 1,
    ),
  )..logoBytes = _png(),
);

void main() {
  testWidgets('Success: the login header shows the configured name and logo', (
    tester,
  ) async {
    await pumpApp(tester, branding: _branded());

    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.local_parking_rounded), findsNothing);
  });

  testWidgets('Failure: branding falls back before the first sync', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Parqueadero'), findsOneWidget);
    expect(find.byIcon(Icons.local_parking_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('Security: the pre-auth header exposes no contact fields', (
    tester,
  ) async {
    await pumpApp(tester, branding: _branded());

    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('Cra 7 # 12-34'), findsNothing);
    expect(find.text('+57 300 111 2233'), findsNothing);
  });

  testWidgets('Success: the home AppBar shows the configured name', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin, branding: _branded());

    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('Hola, Juan'), findsOneWidget);
  });
}
