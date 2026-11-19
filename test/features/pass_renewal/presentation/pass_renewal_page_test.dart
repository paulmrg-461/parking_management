import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/pass_renewal/application/pass_renewal_cubit.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_offer.dart';
import 'package:parking_management/features/pass_renewal/presentation/pass_renewal_page.dart';

import '../../../helpers/fake_pass_renewal_repository.dart';
import '../../../helpers/test_app.dart';

const _token = 'abcdef0123456789abcdef0123456789abcdef0123456789';

Future<({List<Uri> opened, PassRenewalCubit cubit})> _pump(
  WidgetTester tester, {
  required FakePassRenewalRepository repository,
  String? token = _token,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  final cubit = PassRenewalCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<PassRenewalCubit>.value(
        value: cubit,
        child: PassRenewalPage(
          token: token,
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    ),
  );
  // Polling rebuilds the page: `pumpAndSettle` would never finish.
  await tester.pump();
  await tester.pump();
  return (opened: opened, cubit: cubit);
}

void main() {
  testWidgets('Success: shows masked plate, period and amount', (tester) async {
    await _pump(tester, repository: FakePassRenewalRepository(offer: sampleOffer()));

    expect(find.text('Renueva tu mensualidad'), findsOneWidget);
    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('Vehículo ABC***'), findsOneWidget);
    expect(find.textContaining('Nuevo periodo'), findsOneWidget);
    expect(find.text(r'$80.000'), findsOneWidget);
    expect(find.text('Pagar y renovar'), findsOneWidget);
  });

  testWidgets('Success: skeleton while loading', (tester) async {
    final repository = FakePassRenewalRepository(offer: sampleOffer())
      ..loadGate = Completer<void>().future;
    final pending = repository.loadGate!;
    await _pump(tester, repository: repository);
    expect(find.byType(SkeletonCardList), findsOneWidget);
    expect(find.text('Pagar y renovar'), findsNothing);
    pending.ignore();
  });

  testWidgets('Failure: an unknown token shows the contact hint', (tester) async {
    await _pump(tester, repository: FakePassRenewalRepository());
    expect(
      find.text('Este enlace ya no está disponible. Comunícate con el parqueadero.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a malformed token never calls the backend', (tester) async {
    final repository = FakePassRenewalRepository(offer: sampleOffer());
    await _pump(tester, repository: repository, token: 'short');
    expect(repository.loadCalls, 0);
    expect(
      find.text('Este enlace ya no está disponible. Comunícate con el parqueadero.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a network error shows Retry', (tester) async {
    final repository = FakePassRenewalRepository(
      failure: const NetworkFailure('offline'),
    );
    await _pump(tester, repository: repository);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Success: a paid offer shows the new end date', (tester) async {
    await _pump(
      tester,
      repository: FakePassRenewalRepository(
        offer: sampleOffer(
          status: PassRenewalStatus.paid,
          renewalPeriodStart: DateTime(2026, 12, 1),
          renewalPeriodEnd: DateTime(2026, 12, 31),
        ),
      ),
    );
    expect(find.textContaining('Mensualidad renovada hasta el'), findsOneWidget);
    expect(find.text('Pagar y renovar'), findsNothing);
  });

  testWidgets('Success: pay opens the gateway checkout', (tester) async {
    final harness = await _pump(
      tester,
      repository: FakePassRenewalRepository(offer: sampleOffer()),
    );
    await tester.tap(find.byKey(const Key('pass_renewal_pay')));
    await tester.pump();
    await tester.pump();
    expect(harness.opened, hasLength(1));
    expect(harness.opened.single.toString(), contains('checkout.test'));
  });

  testWidgets('Failure: links off sends the customer to the desk', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakePassRenewalRepository(
        offer: sampleOffer(paymentLinksEnabled: false),
      ),
    );
    expect(
      find.text('El pago en línea no está disponible por ahora; renueva en caja.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pass_renewal_pay')), findsNothing);
  });

  testWidgets('A11y: the pay action meets the 48 dp target', (tester) async {
    await _pump(tester, repository: FakePassRenewalRepository(offer: sampleOffer()));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
