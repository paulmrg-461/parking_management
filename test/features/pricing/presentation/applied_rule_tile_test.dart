import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/pricing/domain/entities/fare_pricing.dart';
import 'package:parking_management/features/pricing/presentation/applied_rule_tile.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: shows the rule name, percent and delta', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: AppliedRuleTile(
            pricing: FarePricing(
              ruleName: 'Alta ocupacion',
              multiplierBps: 12000,
              delta: 1800,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Alta ocupacion'), findsOneWidget);
    expect(find.textContaining('+20 %'), findsOneWidget);
    expect(find.textContaining(r'$1.800'), findsOneWidget);
  });

  testWidgets('Success: a discount prints a negative delta', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: AppliedRuleTile(
            pricing: FarePricing(
              ruleName: 'Noche valle',
              multiplierBps: 9000,
              delta: -600,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('-10 %'), findsOneWidget);
    expect(find.textContaining(r'-$600'), findsOneWidget);
  });
}
