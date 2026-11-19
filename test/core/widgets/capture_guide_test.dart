import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/capture_guide.dart';

import '../../helpers/test_app.dart';

void main() {
  test('slotForIndex clamps to detail and guards negatives', () {
    expect(slotForIndex(0), AngleSlot.frontLeft);
    expect(slotForIndex(4), AngleSlot.detail);
    expect(slotForIndex(9), AngleSlot.detail);
    expect(slotForIndex(-1), AngleSlot.frontLeft);
  });

  testWidgets('banner shows the localized next photo and rules', (tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: AngleGuideBanner(captured: 2))),
    );
    expect(find.textContaining('esquina trasera derecha'), findsOneWidget);
    expect(find.textContaining('3 m'), findsOneWidget);
  });

  testWidgets('chips mark the captured slots', (tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: AngleSlotChips(captured: 2))),
    );
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byKey(const Key('guide_slot_4')), findsOneWidget);
  });

  testWidgets('illustration opens and closes', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAngleIllustration(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_illustration')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_illustration')), findsNothing);
  });

  test('no color literals outside the theme', () {
    final source = File('lib/core/widgets/capture_guide.dart').readAsStringSync();
    expect(source.contains('Color(0x'), isFalse);
    expect(source.contains('Colors.black'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
  });

  testWidgets('a11y: touch targets and labels', (tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: AngleGuideBanner(captured: 0))),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
