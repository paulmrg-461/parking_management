import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';
import 'package:parking_management/features/invoicing/presentation/widgets/fiscal_customer_form.dart';

import '../../../helpers/test_app.dart';

const _config = FiscalConfig(mode: FiscalMode.onRequest);

Future<FiscalCustomer? Function()> _pumpDialog(WidgetTester tester) async {
  FiscalCustomer? result;
  tester.view.physicalSize = const Size(700, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showFiscalCustomerDialog(context, config: _config);
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
  testWidgets('issues with the normalized customer', (tester) async {
    final result = await _pumpDialog(tester);

    await tester.tap(find.byKey(const Key('fiscal_customer_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('fiscal_doc_number')),
      ' 900 123 456 ',
    );
    await tester.enterText(find.byKey(const Key('fiscal_name')), ' Empresa SAS ');
    await tester.tap(find.byKey(const Key('fiscal_issue_confirm')));
    await tester.pumpAndSettle();

    expect(result(), isNotNull);
    expect(result()!.documentNumber, '900123456');
    expect(result()!.name, 'Empresa SAS');
  });

  testWidgets('invalid data keeps the dialog open', (tester) async {
    final result = await _pumpDialog(tester);

    await tester.tap(find.byKey(const Key('fiscal_customer_toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fiscal_doc_number')), '1');
    await tester.enterText(find.byKey(const Key('fiscal_name')), 'A');
    await tester.tap(find.byKey(const Key('fiscal_issue_confirm')));
    await tester.pumpAndSettle();

    expect(result(), isNull);
    expect(find.byKey(const Key('fiscal_issue_dialog')), findsOneWidget);
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await _pumpDialog(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('the form is hidden when the mode is off', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: FiscalCustomerForm(
            config: FiscalConfig(mode: FiscalMode.off),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('fiscal_customer_form')), findsNothing);
  });
}
