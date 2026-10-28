import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/shifts/presentation/widgets/cash_count_sheet.dart';

import '../../../helpers/test_app.dart';

void main() {
  Future<int?> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? result;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showCashCountSheet(context);
              },
              child: const Text('count'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('count'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Success: quantities add up to the drawer total', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byKey(const Key('cash_qty_50000')), '2');
    await tester.enterText(find.byKey(const Key('cash_qty_10000')), '3');
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Usar \$130.000'), findsOneWidget);
  });

  testWidgets('Failure: an empty drawer cannot be used', (tester) async {
    await pumpSheet(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Usar \$0'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Security: the sheet returns the counted total, not typed text',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? result;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showCashCountSheet(context);
              },
              child: const Text('count'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('count'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('cash_qty_100000')), '1');
    await tester.enterText(find.byKey(const Key('cash_qty_100')), '7');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Usar \$100.700'));
    await tester.pumpAndSettle();

    expect(result, 100700);
  });
}
