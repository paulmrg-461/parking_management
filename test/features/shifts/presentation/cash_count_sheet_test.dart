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

  testWidgets('Security: the sheet returns the counted total, not typed text', (
    tester,
  ) async {
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

  testWidgets('A11y: each quantity field names its denomination', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpSheet(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('cash_qty_50000'))),
      matchesSemantics(
        label: r'Cantidad de $50.000',
        isTextField: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('Success: the keyboard moves field to field and ends on done', (
    tester,
  ) async {
    await pumpSheet(tester);

    TextField field(String key) =>
        tester.widget<TextField>(find.byKey(Key(key)));
    expect(field('cash_qty_100000').textInputAction, TextInputAction.next);
    expect(field('cash_qty_100').textInputAction, TextInputAction.done);
    expect(field('cash_qty_100').decoration?.isDense, isNot(isTrue));
  });

  testWidgets('A11y: the sheet lifts above the on-screen keyboard', (
    tester,
  ) async {
    await pumpSheet(tester);
    final before = tester.getBottomLeft(find.byType(FilledButton).last).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final after = tester.getBottomLeft(find.byType(FilledButton).last).dy;
    expect(after, lessThanOrEqualTo(before - 300 + 1));
    expect(tester.takeException(), isNull);
  });
}
