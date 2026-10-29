import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/about/presentation/about_developer_page.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: shows the DevPaul identity and the authorship notices', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const AboutDeveloperPage()));

    expect(find.text('DevPaul'), findsOneWidget);
    expect(find.textContaining('Paul Realpe'), findsWidgets);
    // Hero chip + app card footer + page footer.
    expect(find.text('Hecho por DevPaul'), findsNWidgets(3));
    expect(
      find.text('© 2026 DevPaul. Todos los derechos reservados.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Logotipo de DevPaul'), findsOneWidget);
  });

  testWidgets('Success: a link opens the developer profile', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      testApp(
        AboutDeveloperPage(
          launch: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Sitio web'));
    await tester.pumpAndSettle();

    expect(opened, Uri.parse('https://devpaul.pro'));
  });

  testWidgets('Failure: a link that cannot open reports it', (tester) async {
    await tester.pumpWidget(
      testApp(AboutDeveloperPage(launch: (_) async => false)),
    );

    await tester.ensureVisible(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir el enlace'), findsOneWidget);
  });

  testWidgets('A11y: the page meets touch and contrast guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const AboutDeveloperPage()));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
