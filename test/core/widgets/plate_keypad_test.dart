import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/plate_keypad.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> pumpKeypad(
    WidgetTester tester,
    TextEditingController controller, {
    int maxLength = 20,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: PlateKeypad(
              controller: controller,
              maxLength: maxLength,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: keys build an uppercase plate', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpKeypad(tester, controller);

    for (final key in ['A', 'B', 'C', '1', '2', '3']) {
      await tester.tap(find.widgetWithText(OutlinedButton, key));
      await tester.pump();
    }

    expect(controller.text, 'ABC123');
  });

  testWidgets('Failure: backspace and clear reset the field', (tester) async {
    final controller = TextEditingController(text: 'XYZ99');
    addTearDown(controller.dispose);
    await pumpKeypad(tester, controller);

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pump();
    expect(controller.text, 'XYZ9');

    await tester.tap(find.byTooltip('Limpiar'));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('Security: the field never exceeds its maximum length', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ABCDE');
    addTearDown(controller.dispose);
    await pumpKeypad(tester, controller, maxLength: 5);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Z'));
    await tester.pump();

    expect(controller.text, 'ABCDE');
  });
}
