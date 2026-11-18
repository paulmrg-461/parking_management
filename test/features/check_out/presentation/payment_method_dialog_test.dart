import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/money/currency.dart';
import 'package:parking_management/core/money/money.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/fare/fare_quote.dart';
import 'package:parking_management/features/check_out/presentation/payment_method_dialog.dart';
import 'package:parking_management/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:parking_management/features/loyalty/presentation/desk_loyalty_section.dart';

import '../../../helpers/test_app.dart';

const _preview = CheckOutPreview(sessionId: 1, amount: 22000);
final _confirm = find.byKey(const Key('checkout_confirm'));

Future<CheckoutChoice? Function()> pumpDialog(
  WidgetTester tester, {
  CheckOutPreview? preview = _preview,
  PaymentMethod initialMethod = PaymentMethod.cash,
  Size size = const Size(800, 1400),
  bool canDiscount = false,
  LoyaltyDeskOptions? loyalty,
}) async {
  CheckoutChoice? result;
  tester.view.physicalSize = size;
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
                canDiscount: canDiscount,
                preview: preview,
                initialMethod: initialMethod,
                loyalty: loyalty,
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

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect((result())?.cashReceived, 30000);
    expect((result())?.method, PaymentMethod.cash);
  });

  testWidgets('Security: a USD site prefixes and formats the cash change', (
    tester,
  ) async {
    Money.configure(Currency.usd);
    addTearDown(() => Money.configure(Currency.cop));
    await pumpDialog(
      tester,
      preview: const CheckOutPreview(sessionId: 1, amount: 500),
    );

    await tester.enterText(
      find.byKey(const Key('checkout_cash_received')),
      '10.00',
    );
    await tester.pump();

    expect(find.text('US\$5.00'), findsWidgets);
  });

  testWidgets('A11y: the four payment methods fit a phone dialog', (
    tester,
  ) async {
    await pumpDialog(tester, size: const Size(400, 800));

    expect(tester.takeException(), isNull);
    for (final label in [
      'Efectivo',
      'Tarjeta',
      'Transferencia',
      'Mensualidad',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
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

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(find.text('El efectivo recibido no cubre el total'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('Success: card asks debit or credit', (tester) async {
    final result = await pumpDialog(tester, initialMethod: PaymentMethod.card);

    expect(find.text('Tipo de tarjeta'), findsOneWidget);
    expect(find.text('Débito'), findsOneWidget);

    await tester.tap(find.text('Crédito'));
    await tester.pump();
    await tester.tap(_confirm);
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

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect((result())?.cashReceived, isNull);
    expect((result())?.cardType, CardType.debit);
  });

  group('lost ticket', () {
    const lostPreview = CheckOutPreview(
      sessionId: 1,
      amount: 6000,
      lostTicketAmount: 30000,
    );

    Future<void> checkLostTicket(WidgetTester tester) async {
      await tester.tap(find.text('Ticket perdido'));
      await tester.pumpAndSettle();
    }

    testWidgets('Success: the amount due becomes the lost-ticket amount', (
      tester,
    ) async {
      await pumpDialog(tester, preview: lostPreview);
      await checkLostTicket(tester);

      await tester.enterText(
        find.byKey(const Key('checkout_cash_received')),
        '20000',
      );
      await tester.pump();

      // 20.000 covers the regular 6.000 but not the 30.000 lost-ticket fee.
      expect(find.text('Falta'), findsOneWidget);
      expect(find.text(r'$10.000'), findsOneWidget);
    });

    testWidgets('Failure: an older server (no lost amount) keeps the fare', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        preview: const CheckOutPreview(sessionId: 1, amount: 6000),
      );
      await checkLostTicket(tester);

      await tester.enterText(
        find.byKey(const Key('checkout_cash_received')),
        '10000',
      );
      await tester.pump();

      expect(find.text('Cambio'), findsOneWidget);
      expect(find.text(r'$4.000'), findsOneWidget);
    });

    testWidgets(
      'Security: a lost ticket can never be charged to a monthly pass',
      (tester) async {
        final result = await pumpDialog(
          tester,
          preview: lostPreview,
          initialMethod: PaymentMethod.monthlyPass,
        );
        await checkLostTicket(tester);

        await tester.tap(find.text('Mensualidad'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'perdido');
        await tester.tap(_confirm);
        await tester.pumpAndSettle();

        expect(result()?.lostTicket, isTrue);
        expect(result()?.method, isNot(PaymentMethod.monthlyPass));
      },
    );
  });

  group('charge button and totals', () {
    testWidgets('Success: the primary action names the amount due', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(find.text(r'Cobrar $22.000'), findsOneWidget);
    });

    testWidgets('Failure: without a preview the action stays generic', (
      tester,
    ) async {
      await pumpDialog(tester, preview: null);

      expect(find.widgetWithText(FilledButton, 'Confirmar'), findsOneWidget);
      expect(find.textContaining(r'Cobrar $'), findsNothing);
    });

    testWidgets('Success: typing a discount refreshes the total and change', (
      tester,
    ) async {
      await pumpDialog(tester, canDiscount: true);
      expect(
        find.byKey(const Key('checkout_due_after_discount')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('checkout_discount_amount')),
        '2000',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('checkout_due_after_discount')),
        findsOneWidget,
      );
      expect(find.text(r'$20.000'), findsOneWidget);
      expect(find.text(r'Cobrar $20.000'), findsOneWidget);
    });

    testWidgets('Failure: a discount without reason flags the reason field', (
      tester,
    ) async {
      final result = await pumpDialog(tester, canDiscount: true);

      await tester.enterText(
        find.byKey(const Key('checkout_discount_amount')),
        '2000',
      );
      await tester.pump();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      final reason = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('checkout_discount_reason')),
          matching: find.byType(TextField),
        ),
      );
      expect(reason.decoration?.errorText, 'Indica el motivo del descuento');
      expect(result(), isNull);
    });

    testWidgets('Failure: a cash shortfall is shown on the cash field', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.enterText(
        find.byKey(const Key('checkout_cash_received')),
        '1000',
      );
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      final cash = tester.widget<TextField>(
        find.byKey(const Key('checkout_cash_received')),
      );
      expect(
        cash.decoration?.errorText,
        'El efectivo recibido no cubre el total',
      );
    });
  });

  group('cash shortcuts', () {
    testWidgets('Success: Exacto fills the amount due and confirms on done', (
      tester,
    ) async {
      final result = await pumpDialog(tester);

      await tester.tap(find.byKey(const Key('checkout_cash_exact')));
      await tester.pump();
      expect(find.text('22000'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(result()?.cashReceived, 22000);
    });

    testWidgets('Success: bill chips offer the smallest notes that cover it', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        preview: const CheckOutPreview(sessionId: 1, amount: 6000),
      );

      expect(find.widgetWithText(ActionChip, r'$10.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, r'$20.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, r'$50.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, r'$5.000'), findsNothing);

      await tester.tap(find.widgetWithText(ActionChip, r'$10.000'));
      await tester.pump();
      expect(find.text('Cambio'), findsOneWidget);
      expect(find.text(r'$4.000'), findsOneWidget);
    });

    testWidgets('A11y: the cash field is focused and chips meet 48 dp', (
      tester,
    ) async {
      await pumpDialog(tester, size: const Size(400, 800));

      final cash = tester.widget<TextField>(
        find.byKey(const Key('checkout_cash_received')),
      );
      expect(cash.autofocus, isTrue);
      expect(cash.textInputAction, TextInputAction.done);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  group('loyalty reward', () {
    CheckOutPreview rewardPreview({
      bool available = true,
      bool applied = false,
      String? reason = 'operator_choice_pending',
    }) => CheckOutPreview(
      sessionId: 1,
      amount: 6000,
      quote: FareQuote(
        sessionId: 1,
        baseAmount: 6000,
        gross: 6000,
        reward: {
          'available': available,
          'applied': applied,
          'reason': reason,
          'progress': {'visits': 2, 'required': 5},
        },
      ),
    );

    testWidgets('operator mode shows the use reward switch', (tester) async {
      await pumpDialog(
        tester,
        preview: rewardPreview(),
        loyalty: LoyaltyDeskOptions(
          choose: (choice) async => rewardPreview(applied: true),
        ),
      );

      expect(find.byKey(const Key('desk_loyalty_section')), findsOneWidget);
      expect(find.byKey(const Key('loyalty_use_reward')), findsOneWidget);
      expect(find.text('Visita 3 de 5'), findsOneWidget);
    });

    testWidgets('switch calls choose and refreshes the preview', (
      tester,
    ) async {
      final choices = <LoyaltyChoice>[];
      await pumpDialog(
        tester,
        preview: rewardPreview(),
        loyalty: LoyaltyDeskOptions(
          choose: (choice) async {
            choices.add(choice);
            return rewardPreview(applied: true, reason: null);
          },
        ),
      );

      await tester.tap(find.byKey(const Key('loyalty_use_reward')));
      await tester.pumpAndSettle();

      expect(choices, [LoyaltyChoice.redeem]);
      expect(find.byKey(const Key('loyalty_dont_use')), findsOneWidget);
    });

    testWidgets('auto mode shows the reward line with do not use now', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        preview: rewardPreview(applied: true, reason: null),
        loyalty: LoyaltyDeskOptions(
          choose: (choice) async => rewardPreview(),
        ),
      );

      expect(find.text('Recompensa de fidelidad'), findsOneWidget);
      expect(find.byKey(const Key('loyalty_dont_use')), findsOneWidget);
    });

    testWidgets('skip refreshes the preview without the line', (tester) async {
      final choices = <LoyaltyChoice>[];
      await pumpDialog(
        tester,
        preview: rewardPreview(applied: true, reason: null),
        loyalty: LoyaltyDeskOptions(
          choose: (choice) async {
            choices.add(choice);
            return rewardPreview(reason: 'skipped');
          },
        ),
      );

      await tester.tap(find.byKey(const Key('loyalty_dont_use')));
      await tester.pumpAndSettle();

      expect(choices, [LoyaltyChoice.skip]);
      expect(find.byKey(const Key('loyalty_dont_use')), findsNothing);
      expect(find.text('No usar ahora'), findsOneWidget);
    });

    testWidgets('choose failure keeps the dialog and shows the message', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        preview: rewardPreview(applied: true, reason: null),
        loyalty: LoyaltyDeskOptions(
          choose: (choice) async => throw const ValidationFailure(
            'NoRewardAvailableError',
            'NoRewardAvailableError',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('loyalty_dont_use')));
      await tester.pumpAndSettle();

      expect(find.text('Esta placa no tiene recompensa disponible'), findsOneWidget);
      expect(find.byKey(const Key('desk_loyalty_section')), findsOneWidget);
    });

    testWidgets('no loyalty section when the preview has no reward', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(find.byKey(const Key('desk_loyalty_section')), findsNothing);
    });
  });
}
