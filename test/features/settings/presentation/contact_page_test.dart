import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/settings/presentation/contact_page.dart';

import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/test_app.dart';

const _full = ParkingSettings(
  name: 'Parqueadero Central',
  address: 'Cra 7 # 12-34',
  schedule: 'Lun a Dom 6am-10pm',
  phone: '+57 300 111 2233',
  website: 'parqueaderocentral.co',
  whatsapp: '+57 300 111 2233',
);

Future<BrandingCubit> pumpContact(
  WidgetTester tester,
  FakeParkingSettingsRepository repository,
) async {
  final branding = BrandingCubit(repository);
  await branding.load();
  await tester.pumpWidget(
    BlocProvider<BrandingCubit>.value(
      value: branding,
      child: testApp(const ContactPage()),
    ),
  );
  await tester.pumpAndSettle();
  return branding;
}

void main() {
  testWidgets('Success: renders the configured identity and contact rows', (
    tester,
  ) async {
    await pumpContact(tester, FakeParkingSettingsRepository(_full));

    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('Cra 7 # 12-34'), findsOneWidget);
    expect(find.text('Lun a Dom 6am-10pm'), findsOneWidget);
    expect(find.text('+57 300 111 2233'), findsNWidgets(2));
    expect(find.text('parqueaderocentral.co'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('Failure: falls back to the default name without cached settings', (
    tester,
  ) async {
    await pumpContact(tester, FakeParkingSettingsRepository());

    expect(find.text('Parqueadero'), findsOneWidget);
    expect(find.text('Teléfono'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
  });

  testWidgets('Security: no WhatsApp action when the number is unconfigured', (
    tester,
  ) async {
    await pumpContact(
      tester,
      FakeParkingSettingsRepository(
        const ParkingSettings(name: 'Parqueadero Central'),
      ),
    );

    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
  });
}
