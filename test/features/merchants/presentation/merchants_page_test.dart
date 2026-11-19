import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/merchants/application/merchant_settlement_cubit.dart';
import 'package:parking_management/features/merchants/application/merchants_cubit.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';
import 'package:parking_management/features/merchants/presentation/merchants_page.dart';

import '../../../helpers/fake_merchant_repository.dart';
import '../../../helpers/test_app.dart';

Future<MerchantsCubit> _pump(
  WidgetTester tester,
  FakeMerchantRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = MerchantsCubit(repository);
  addTearDown(cubit.close);
  final settlement = MerchantSettlementCubit(repository);
  addTearDown(settlement.close);
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<MerchantsCubit>.value(value: cubit),
          BlocProvider<MerchantSettlementCubit>.value(value: settlement),
        ],
        child: const MerchantsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Empty: no agreements offers the first one', (tester) async {
    final repository = FakeMerchantRepository(merchants: []);
    await _pump(tester, repository);

    expect(find.textContaining('Aún no hay convenios'), findsOneWidget);
    expect(find.byKey(const Key('merchant_add')), findsOneWidget);
  });

  testWidgets('Success: the list shows usage and pending counts', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeMerchantRepository(
        merchants: [
          const Merchant(
            id: 1,
            name: 'Cafe Uno',
            kind: MerchantBenefitKind.percentage,
            value: 10,
            billingMode: MerchantBillingMode.merchantPaid,
            usedToday: 2,
            usedMonth: 9,
            pendingNow: 1,
          ),
        ],
      ),
    );

    expect(find.text('Cafe Uno'), findsOneWidget);
    expect(find.text('10% de descuento'), findsOneWidget);
    expect(find.text('Hoy 2 · Mes 9'), findsOneWidget);
    expect(find.text('1 pendiente'), findsOneWidget);
  });

  testWidgets('Security: credentials are shown once after creating', (
    tester,
  ) async {
    final repository = FakeMerchantRepository(merchants: [])
      ..credentialsToReturn = const MerchantCredentials(
        merchantId: 9,
        pin: '123456',
        token: 'abcdef',
        linkPath: '/validate?m=abcdef',
      );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('merchant_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('merchant_name')), 'Nuevo');
    await tester.enterText(find.byKey(const Key('merchant_value')), '10');
    await tester.tap(find.byKey(const Key('merchant_save')));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales del comercio'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(repository.saved.single.name, 'Nuevo');

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Credenciales del comercio'), findsNothing);
  });

  testWidgets('Success: the policy dialog saves the maximum', (tester) async {
    final repository = FakeMerchantRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Convenios por vehículo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('merchant_policy_value')), '3');
    await tester.tap(find.byKey(const Key('merchant_policy_save')));
    await tester.pumpAndSettle();

    expect(repository.policy, 3);
    expect(repository.policySaves, 1);
  });

  testWidgets('Failure: a failed load offers Retry', (tester) async {
    final repository = FakeMerchantRepository()
      ..listError = const NetworkFailure('offline');
    await _pump(tester, repository);

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
