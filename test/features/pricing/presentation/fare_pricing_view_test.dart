import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/fare/fare_quote.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/presentation/widgets/fare_breakdown_view.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: the breakdown shows the locked rule', (tester) async {
    const preview = CheckOutPreview(
      sessionId: 1,
      amount: 10800,
      quote: FareQuote(
        sessionId: 1,
        baseAmount: 9000,
        gross: 10800,
        pricing: {
          'rule_name': 'Alta ocupacion',
          'multiplier_bps': 12000,
          'delta': 1800,
        },
      ),
    );
    await tester.pumpWidget(
      testApp(const Scaffold(body: FareBreakdownView(preview: preview))),
    );

    expect(find.byKey(const Key('applied_rule_tile')), findsOneWidget);
    expect(find.textContaining('Alta ocupacion'), findsOneWidget);
    expect(find.textContaining('+20 %'), findsOneWidget);
  });

  testWidgets('Success: no rule means no tile', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: FareBreakdownView(
            preview: CheckOutPreview(sessionId: 1, amount: 9000),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('applied_rule_tile')), findsNothing);
  });
}
