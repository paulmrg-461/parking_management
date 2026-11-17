import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/presentation/payment_method_dialog.dart';

import '../../../helpers/test_app.dart';

final _confirm = find.byKey(const Key('checkout_confirm'));
final _onlineBox = find.byKey(const Key('checkout_online_box'));

Future<CheckoutChoice? Function()> _pump(
  WidgetTester tester, {
  required CheckOutPreview preview,
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
                canDiscount: true,
                preview: preview,
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
  testWidgets('Success: paid inside the grace window hides the cash step', (
    tester,
  ) async {
    final result = await _pump(
      tester,
      preview: const CheckOutPreview(
        sessionId: 1,
        amount: 8000,
        onlinePaidAmount: 8000,
        amountDue: 0,
        graceActive: true,
      ),
    );

    expect(_onlineBox, findsOneWidget);
    expect(find.text('Pagado en línea'), findsOneWidget);
    expect(find.text('Sin cobro en caja: ya pagó en línea'), findsOneWidget);
    expect(find.byKey(const Key('checkout_cash_received')), findsNothing);
    expect(find.text('Efectivo'), findsNothing);
    expect(find.text('Confirmar salida'), findsOneWidget);

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    // The server owns the method: the client still sends a normal one.
    expect(result()!.method, PaymentMethod.cash);
  });

  testWidgets('Success: after the window only the difference is due', (
    tester,
  ) async {
    final result = await _pump(
      tester,
      preview: const CheckOutPreview(
        sessionId: 1,
        amount: 10000,
        onlinePaidAmount: 6000,
        amountDue: 4000,
        graceActive: false,
      ),
    );

    expect(find.text('Saldo en caja'), findsOneWidget);
    expect(find.text('Venció la tolerancia de salida; se cobra la diferencia'), findsOneWidget);
    expect(find.byKey(const Key('checkout_cash_received')), findsOneWidget);
    expect(find.text('Cobrar \$4.000'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '3000',
    );
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    // Below the balance: the dialog stays open with the error.
    expect(result(), isNull);
    expect(find.text('El efectivo recibido no cubre el total'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '5000',
    );
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    expect(result()!.cashReceived, 5000);
  });

  testWidgets('Success: a discount reduces only the desk balance', (
    tester,
  ) async {
    final result = await _pump(
      tester,
      preview: const CheckOutPreview(
        sessionId: 1,
        amount: 10000,
        onlinePaidAmount: 6000,
        amountDue: 4000,
        graceActive: false,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('checkout_discount_amount')),
      '1000',
    );
    await tester.enterText(
      find.byKey(const Key('checkout_discount_reason')),
      'cortesia',
    );
    await tester.pump();
    expect(find.byKey(const Key('checkout_due_after_discount')), findsOneWidget);
    expect(find.text('Cobrar \$3.000'), findsOneWidget);

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    expect(result()!.discountAmount, 1000);
  });
}
