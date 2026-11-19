import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/fare/fare_adjustment.dart';
import 'package:parking_management/core/fare/fare_quote.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/merchants/presentation/desk_merchant_section.dart';

import '../../../helpers/fake_merchant_repository.dart';
import '../../../helpers/test_app.dart';

const _withLine = CheckOutPreview(
  sessionId: 1,
  amount: 9000,
  quote: FareQuote(
    sessionId: 1,
    baseAmount: 9000,
    gross: 9000,
    adjustments: [
      FareAdjustment(
        type: FareAdjustmentType.merchant,
        refId: 5,
        label: 'Cafe Uno',
        kind: 'percentage',
        amount: 4500,
      ),
    ],
    adjustmentsTotal: 4500,
    amountDue: 4500,
  ),
);

Future<CheckOutPreview Function()> _pump(
  WidgetTester tester, {
  required MerchantDeskOptions options,
  CheckOutPreview preview = const CheckOutPreview(sessionId: 1, amount: 9000),
  bool canRevoke = true,
}) async {
  var current = preview;
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DeskMerchantSection(
            merchants: options,
            preview: current,
            canRevoke: canRevoke,
            onChanged: (next) => setState(() => current = next),
          ),
        ),
      ),
    ),
  );
  return () => current;
}

void main() {
  testWidgets('Success: applying an agreement refreshes the preview', (
    tester,
  ) async {
    var applied = 0;
    final current = await _pump(
      tester,
      options: MerchantDeskOptions(
        options: [sampleMerchant],
        apply: (merchantId) async {
          applied++;
          return _withLine;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('desk_merchant_section')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desk_merchant_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafe Uno').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desk_merchant_apply')));
    await tester.pumpAndSettle();

    expect(applied, 1);
    expect(current().quote?.adjustments, hasLength(1));
    expect(find.text('Convenio Cafe Uno'), findsOneWidget);
  });

  testWidgets('Security: removing an agreement asks for a reason', (
    tester,
  ) async {
    String? reason;
    final current = await _pump(
      tester,
      preview: _withLine,
      options: MerchantDeskOptions(
        options: [sampleMerchant],
        apply: (_) async => _withLine,
        revoke: (validationId, value) async {
          reason = value;
          return const CheckOutPreview(sessionId: 1, amount: 9000);
        },
      ),
    );

    await tester.tap(find.byKey(const Key('desk_merchant_section')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('desk_merchant_reason')),
      'prueba',
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(reason, 'prueba');
    expect(current().quote, isNull);
  });

  testWidgets('Security: an operator does not see the remove action', (
    tester,
  ) async {
    await _pump(
      tester,
      preview: _withLine,
      canRevoke: false,
      options: MerchantDeskOptions(
        options: [sampleMerchant],
        apply: (_) async => _withLine,
      ),
    );

    await tester.tap(find.byKey(const Key('desk_merchant_section')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
