import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_rule.dart';
import 'package:parking_management/features/pricing/presentation/pricing_rule_dialog.dart';

import '../../../helpers/test_app.dart';

Future<PricingRuleDraft? Function()> _pump(
  WidgetTester tester, {
  PricingRule? rule,
}) async {
  PricingRuleDraft? result;
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showPricingRuleDialog(context, rule: rule);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('Failure: the name is required', (tester) async {
    final result = await _pump(tester);

    await tester.tap(find.byKey(const Key('pricing_rule_save')));
    await tester.pumpAndSettle();

    expect(result(), isNull);
    expect(find.text('Campo obligatorio'), findsOneWidget);
  });

  testWidgets('Failure: an inverted band is rejected', (tester) async {
    final result = await _pump(tester);

    await tester.enterText(find.byKey(const Key('pricing_rule_name')), 'Banda');
    await tester.enterText(find.byKey(const Key('pricing_rule_min')), '90');
    await tester.enterText(find.byKey(const Key('pricing_rule_max')), '80');
    await tester.tap(find.byKey(const Key('pricing_rule_save')));
    await tester.pumpAndSettle();

    expect(result(), isNull);
    expect(find.textContaining('fuera de rango'), findsOneWidget);
  });

  testWidgets('Success: saves the draft with minutes and the bitmask', (
    tester,
  ) async {
    final result = await _pump(tester);

    await tester.enterText(find.byKey(const Key('pricing_rule_name')), 'Alta');
    await tester.enterText(find.byKey(const Key('pricing_rule_min')), '80');
    await tester.enterText(find.byKey(const Key('pricing_rule_max')), '100');
    await tester.enterText(
      find.byKey(const Key('pricing_rule_multiplier')),
      '120',
    );
    await tester.tap(find.text('6'));
    await tester.tap(find.byKey(const Key('pricing_rule_save')));
    await tester.pumpAndSettle();

    final draft = result();
    expect(draft, isNotNull);
    expect(draft!.name, 'Alta');
    expect(draft.multiplierBps, 12000);
    expect(draft.minOccupancyPct, 80);
    expect(draft.weekdays, 32);
  });

  testWidgets('Success: editing prefills the rule', (tester) async {
    final result = await _pump(
      tester,
      rule: const PricingRule(
        id: 7,
        name: 'Noche valle',
        priority: 100,
        multiplierBps: 9000,
        group: 'car',
        fromMinute: 22 * 60,
        toMinute: 6 * 60,
      ),
    );

    expect(find.text('Noche valle'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pricing_rule_save')));
    await tester.pumpAndSettle();

    final draft = result();
    expect(draft?.id, 7);
    expect(draft?.fromMinute, 22 * 60);
    expect(draft?.toMinute, 6 * 60);
  });
}
