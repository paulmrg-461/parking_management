import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';
import 'package:parking_management/features/online_payments/application/online_payment_cubit.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_status.dart';
import 'package:parking_management/features/online_payments/presentation/widgets/pay_online_panel.dart';

import '../../../helpers/test_app.dart';
import '../application/online_payment_cubit_test.dart'
    show FakeOnlinePaymentRepository;

PublicSessionSummary _summary({
  int amountDue = 6000,
  bool enabled = true,
  String status = 'open',
  int paid = 0,
  DateTime? graceUntil,
}) => PublicSessionSummary(
  sessionId: 55,
  status: status,
  durationSeconds: 3600,
  currency: 'COP',
  amount: amountDue,
  onlinePaymentsEnabled: enabled,
  onlinePaidAmount: paid,
  amountDue: amountDue,
  graceUntil: graceUntil,
);

Future<({List<Uri> opened, OnlinePaymentCubit cubit})> _pump(
  WidgetTester tester, {
  required PublicSessionSummary summary,
  FakeOnlinePaymentRepository? repository,
  String? payReference,
}) async {
  final opened = <Uri>[];
  final cubit = OnlinePaymentCubit(
    repository ?? FakeOnlinePaymentRepository(),
  );
  await tester.pumpWidget(
    BlocProvider<OnlinePaymentCubit>.value(
      value: cubit,
      child: testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: PayOnlinePanel(
              summary: summary,
              plate: 'ABC123',
              payReference: payReference,
              launch: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (opened: opened, cubit: cubit);
}

void main() {
  testWidgets('Success: the panel shows the amount due and the pay action', (
    tester,
  ) async {
    await _pump(tester, summary: _summary());
    expect(find.text('Paga desde tu celular'), findsOneWidget);
    expect(find.text('Pagar en línea'), findsOneWidget);
    expect(find.text('Tarjeta, PSE o Nequi. Después de pagar tienes 15 minutos para salir.'), findsOneWidget);
  });

  testWidgets('Security: the panel is hidden when the lot switch is off', (
    tester,
  ) async {
    await _pump(tester, summary: _summary(enabled: false));
    expect(find.text('Paga desde tu celular'), findsNothing);
  });

  testWidgets('Success: nothing due hides the panel', (tester) async {
    await _pump(tester, summary: _summary(amountDue: 0));
    expect(find.text('Paga desde tu celular'), findsNothing);
  });

  testWidgets('Success: pay opens the gateway checkout url', (tester) async {
    final harness = await _pump(tester, summary: _summary());
    await tester.tap(find.byKey(const Key('online_pay_action')));
    await tester.pumpAndSettle();
    expect(harness.opened, hasLength(1));
    expect(harness.opened.single.toString(), contains('checkout.test'));
    await harness.cubit.close();
  });

  testWidgets('Failure: a declined payment shows the retry copy', (
    tester,
  ) async {
    final repository = FakeOnlinePaymentRepository(
      statuses: [
        const PaymentIntentStatus(
          status: PaymentStatus.declined,
          amount: 6000,
          sessionId: 55,
        ),
      ],
    );
    final harness = await _pump(
      tester,
      summary: _summary(),
      repository: repository,
      payReference: 'PM-1A2B3C4D5E6F',
    );
    await tester.pumpAndSettle();
    expect(find.text('El pago no fue aprobado. Puedes intentarlo de nuevo.'), findsOneWidget);
    await harness.cubit.close();
  });

  testWidgets('Success: an approved payment shows the exit deadline', (
    tester,
  ) async {
    final repository = FakeOnlinePaymentRepository(
      statuses: [
        PaymentIntentStatus(
          status: PaymentStatus.approved,
          amount: 6000,
          sessionId: 55,
          paidTotal: 6000,
          graceUntil: DateTime(2026, 11, 17, 13, 15),
        ),
      ],
    );
    final harness = await _pump(
      tester,
      summary: _summary(),
      repository: repository,
      payReference: 'PM-1A2B3C4D5E6F',
    );
    await tester.pumpAndSettle();
    expect(find.text('Pago recibido. Muestra esta pantalla al salir.'), findsOneWidget);
    expect(find.textContaining('Sal antes de las'), findsOneWidget);
    await harness.cubit.close();
  });
}
