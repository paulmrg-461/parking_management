import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/presentation/payment_method_dialog.dart';

import '../../../helpers/test_app.dart';

const _preview = CheckOutPreview(sessionId: 1, amount: 22000);

Future<CheckoutChoice? Function()> pumpDialog(
  WidgetTester tester, {
  CheckOutPreview? preview = _preview,
  PaymentMethod initialMethod = PaymentMethod.cash,
}) async {
  CheckoutChoice? result;
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showCheckoutDialog(
                context,
                plate: 'ABC123',
                canDiscount: false,
                preview: preview,
                initialMethod: initialMethod,
              );
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
  testWidgets('Success: cash shows the change for the amount received', (
    tester,
  ) async {
    final result = await pumpDialog(tester);

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '30000',
    );
    await tester.pump();

    expect(find.text('Cambio'), findsOneWidget);
    expect(find.text(r'$8.000'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect((result())?.cashReceived, 30000);
    expect((result())?.method, PaymentMethod.cash);
  });

  testWidgets('Failure: cash below the total blocks the charge', (
    tester,
  ) async {
    final result = await pumpDialog(tester);

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '10000',
    );
    await tester.pump();
    expect(find.text('Falta'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El efectivo recibido no cubre el total'),
      findsOneWidget,
    );
    expect(result(), isNull);
  });

  testWidgets('Success: card asks debit or credit', (tester) async {
    final result = await pumpDialog(
      tester,
      initialMethod: PaymentMethod.card,
    );

    expect(find.text('Tipo de tarjeta'), findsOneWidget);
    expect(find.text('Débito'), findsOneWidget);

    await tester.tap(find.text('Crédito'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect((result())?.cardType, CardType.credit);
    expect((result())?.method, PaymentMethod.card);
  });

  testWidgets('Security: switching to card drops the cash amount', (
    tester,
  ) async {
    final result = await pumpDialog(tester);

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '30000',
    );
    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout_cash_received')), findsNothing);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect((result())?.cashReceived, isNull);
    expect((result())?.cardType, CardType.debit);
  });
}
