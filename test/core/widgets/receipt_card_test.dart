import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/receipt_card.dart';

import '../../helpers/test_app.dart';

ReceiptData _checkOutData() => ReceiptData(
  kind: ReceiptKind.checkOut,
  plate: 'ABC123',
  entryTime: DateTime(2026, 1, 1, 8, 30),
  exitTime: DateTime(2026, 1, 1, 11, 45),
  amountCharged: 12500,
  ticketNumber: 'TCK-000042',
);

void main() {
  testWidgets('check-out receipt formats date, duration and amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ReceiptCard(data: _checkOutData()),
          ),
        ),
      ),
    );

    expect(find.text('01/01/2026 08:30:00'), findsOneWidget);
    expect(find.text('01/01/2026 11:45:00'), findsOneWidget);
    expect(find.text('3 h 15 min'), findsOneWidget);
    expect(find.text(r'$12.500'), findsOneWidget);
    expect(find.text('TCK-000042'), findsOneWidget);
  });

  testWidgets('check-out summary offers Generar recibo and Cerrar', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(Material(child: ReceiptSummaryDialog(data: _checkOutData()))),
    );

    expect(find.text('Generar recibo'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
  });

  testWidgets('Generar recibo opens the full receipt', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showReceiptSummary(context, _checkOutData()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generar recibo'));
    await tester.pumpAndSettle();

    expect(find.text('SALIDA REGISTRADA'), findsOneWidget);
    expect(find.text('TCK-000042'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
  });

  testWidgets('check-in receipt shows photos and no amount', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: ReceiptCard(
              data: ReceiptData(
                kind: ReceiptKind.checkIn,
                plate: 'XYZ999',
                entryTime: DateTime(2026, 1, 1, 9, 0),
                photoCount: 2,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Entrada registrada'), findsNothing);
    expect(find.text('Fotos de evidencia'), findsOneWidget);
    expect(find.text('2 fotos'), findsOneWidget);
    expect(find.text('Salida registrada'), findsNothing);
  });
}
