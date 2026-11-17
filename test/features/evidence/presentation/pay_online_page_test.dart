import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/evidence/application/evidence_cubit.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';
import 'package:parking_management/features/evidence/presentation/public_evidence_page.dart';
import 'package:parking_management/features/online_payments/application/online_payment_cubit.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_status.dart';

import '../../../helpers/fake_evidence_repository.dart';
import '../../../helpers/fake_online_payment_repository.dart';
import '../../../helpers/test_app.dart';

PublicEvidence _evidence({bool enabled = true, int amountDue = 6000}) =>
    PublicEvidence(
      plate: 'ABC123',
      entryTime: DateTime(2026, 11, 17, 8),
      summary: PublicSessionSummary(
        sessionId: 55,
        status: 'open',
        durationSeconds: 7200,
        currency: 'COP',
        amount: amountDue,
        onlinePaymentsEnabled: enabled,
        amountDue: amountDue,
        onlineMinAmount: 1500,
      ),
    );

Future<OnlinePaymentCubit> _pump(
  WidgetTester tester, {
  required PublicEvidence evidence,
  String? payReference,
  FakeOnlinePaymentRepository? onlineRepository,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final evidenceCubit = EvidenceCubit(
    FakeEvidenceRepository(evidence: evidence),
  );
  final onlineCubit = OnlinePaymentCubit(
    onlineRepository ?? FakeOnlinePaymentRepository(),
  );
  addTearDown(evidenceCubit.close);
  addTearDown(onlineCubit.close);
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<EvidenceCubit>.value(value: evidenceCubit),
          BlocProvider<OnlinePaymentCubit>.value(value: onlineCubit),
        ],
        child: PublicEvidencePage(
          sessionId: 55,
          plate: 'ABC123',
          payReference: payReference,
        ),
      ),
    ),
  );
  // The tracking timer rebuilds the panel every few seconds: settle would
  // never finish, so pump a couple of frames instead.
  await tester.pump();
  await tester.pump();
  return onlineCubit;
}

void main() {
  testWidgets('Success: the pay panel appears for an open session', (
    tester,
  ) async {
    await _pump(tester, evidence: _evidence());
    expect(find.text('Paga desde tu celular'), findsOneWidget);
    expect(find.text('Pagar en línea'), findsOneWidget);
  });

  testWidgets('Security: the panel is hidden when the lot switch is off', (
    tester,
  ) async {
    await _pump(tester, evidence: _evidence(enabled: false));
    expect(find.text('Paga desde tu celular'), findsNothing);
  });

  testWidgets('Success: payReference is polled with the plate', (tester) async {
    final repository = FakeOnlinePaymentRepository(
      statuses: [
        const PaymentIntentStatus(
          status: PaymentStatus.pending,
          amount: 6000,
          sessionId: 55,
        ),
      ],
    );
    await _pump(
      tester,
      evidence: _evidence(),
      payReference: 'PM-1A2B3C4D5E6F',
      onlineRepository: repository,
    );
    expect(repository.statusCalls, greaterThanOrEqualTo(1));
    expect(repository.lastReference, 'PM-1A2B3C4D5E6F');
    expect(repository.lastPlate, 'ABC123');
    expect(
      find.text('Aún no confirmamos tu pago. Si ya pagaste, espera un momento.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a closed session never offers the pay panel', (
    tester,
  ) async {
    await _pump(
      tester,
      evidence: PublicEvidence(
        plate: 'ABC123',
        entryTime: DateTime(2026, 11, 17, 8),
        exitTime: DateTime(2026, 11, 17, 10),
        status: 'closed',
        summary: PublicSessionSummary(
          sessionId: 55,
          status: 'closed',
          durationSeconds: 7200,
          currency: 'COP',
          amount: 6000,
          onlinePaymentsEnabled: true,
          amountDue: 0,
        ),
      ),
    );
    expect(find.text('Paga desde tu celular'), findsNothing);
  });
}
