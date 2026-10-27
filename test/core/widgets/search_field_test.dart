import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/search_field.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('Success: typing reports values and shows the clear button', (
    tester,
  ) async {
    final values = <String>[];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SearchField(label: 'Buscar', onChanged: values.add),
        ),
      ),
    );

    expect(find.byIcon(Icons.clear), findsNothing);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(values, ['abc']);
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('Success: the clear button empties the search', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SearchField(label: 'Buscar', onChanged: values.add),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(values.last, '');
    expect(find.byIcon(Icons.clear), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('Security: Escape clears instead of closing the screen', (
    tester,
  ) async {
    final values = <String>[];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SearchField(label: 'Buscar', onChanged: values.add),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(values.last, '');
    expect(find.byType(SearchField), findsOneWidget);
  });
}
