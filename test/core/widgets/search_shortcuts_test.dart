import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/search_field.dart';
import 'package:parking_management/core/widgets/search_shortcuts.dart';

import '../../helpers/test_app.dart';

FocusNode fieldFocus(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!;

Future<void> pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('Success: Ctrl+K focuses the search field', (tester) async {
    await tester.pumpWidget(
      SearchShortcuts(
        child: testApp(
          Scaffold(
            body: SearchField(label: 'Buscar', onChanged: (_) {}),
          ),
        ),
      ),
    );

    expect(fieldFocus(tester).hasFocus, isFalse);

    await pressCtrl(tester, LogicalKeyboardKey.keyK);

    expect(fieldFocus(tester).hasFocus, isTrue);
  });

  testWidgets('Failure: a bare K does not steal focus', (tester) async {
    await tester.pumpWidget(
      SearchShortcuts(
        child: testApp(
          Scaffold(
            body: SearchField(label: 'Buscar', onChanged: (_) {}),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(fieldFocus(tester).hasFocus, isFalse);
  });

  testWidgets('Security: Ctrl+K keeps the typed text intact', (tester) async {
    await tester.pumpWidget(
      SearchShortcuts(
        child: testApp(
          Scaffold(
            body: SearchField(label: 'Buscar', onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'AB123');
    await tester.pump();

    await pressCtrl(tester, LogicalKeyboardKey.keyK);

    expect(fieldFocus(tester).hasFocus, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'AB123',
    );
  });
}
