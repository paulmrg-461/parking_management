import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/help/presentation/help_page.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: shows the sections and expands an article', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const HelpPage()));

    expect(find.text('Ayuda'), findsOneWidget);
    expect(find.text('Primeros pasos'), findsOneWidget);
    expect(find.text('Abrir turno'), findsOneWidget);

    await tester.tap(find.text('Abrir turno'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cuenta el efectivo inicial'), findsOneWidget);
  });

  testWidgets('Success: the search narrows the articles', (tester) async {
    await tester.pumpWidget(testApp(const HelpPage()));

    await tester.enterText(find.byType(TextField), 'reimprimir');
    await tester.pumpAndSettle();

    expect(find.text('Reimprimir un ticket'), findsOneWidget);
    expect(find.text('Abrir turno'), findsNothing);
    expect(find.textContaining('artículos'), findsOneWidget);
  });

  testWidgets('Failure: no matches shows the empty state', (tester) async {
    await tester.pumpWidget(testApp(const HelpPage()));

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(
      find.text('No hay artículos que coincidan con la búsqueda.'),
      findsOneWidget,
    );
  });
}
