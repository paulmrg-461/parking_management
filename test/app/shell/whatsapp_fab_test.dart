import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_settings_repository.dart';

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

BrandingCubit _brandingWith(String whatsapp) => BrandingCubit(
  FakeParkingSettingsRepository(
    ParkingSettings(name: 'Parqueadero Central', whatsapp: whatsapp),
  ),
);

void main() {
  late _RecordingUrlLauncher launcher;

  setUp(() {
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('Success: the floating action opens the wa.me chat', (
    tester,
  ) async {
    await pumpApp(
      tester,
      role: UserRole.operator,
      branding: _brandingWith('+57 300 111 2233'),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(launcher.launched, ['https://wa.me/573001112233']);
  });

  testWidgets('Failure: no floating action when WhatsApp is unconfigured', (
    tester,
  ) async {
    await pumpApp(tester, role: UserRole.admin);

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Security: the launched link carries digits only', (
    tester,
  ) async {
    await pumpApp(
      tester,
      role: UserRole.admin,
      branding: _brandingWith('+57 (300) 111-2233'),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      RegExp(r'^https://wa\.me/\d+$').hasMatch(launcher.launched.single),
      isTrue,
    );
  });
}
