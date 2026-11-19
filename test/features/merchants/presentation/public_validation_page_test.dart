import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/merchants/application/merchant_validation_cubit.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_validation_result.dart';
import 'package:parking_management/features/merchants/presentation/public_validation_page.dart';

import '../../../helpers/fake_merchant_repository.dart';
import '../../../helpers/test_app.dart';

const _token = 'abcdef0123456789abcdef0123456789abcdef0123456789';

Future<MerchantValidationCubit> _pump(
  WidgetTester tester, {
  required FakePublicMerchantRepository repository,
  String? token = _token,
}) async {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = MerchantValidationCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<MerchantValidationCubit>.value(
        value: cubit,
        child: PublicValidationPage(token: token),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('Success: shows the merchant and its benefit', (tester) async {
    await _pump(
      tester,
      repository: FakePublicMerchantRepository(portalResult: samplePortal),
    );

    expect(find.text('Validar parqueo'), findsOneWidget);
    expect(find.text('Cafe Uno'), findsOneWidget);
    expect(find.text('10% de descuento'), findsOneWidget);
    expect(find.byKey(const Key('validate_pin')), findsOneWidget);
  });

  testWidgets('Success: skeleton while loading', (tester) async {
    final repository = FakePublicMerchantRepository(portalResult: samplePortal);
    final gate = Completer<void>();
    repository.portalGate = gate.future;
    await _pump(tester, repository: repository);

    expect(find.byType(SkeletonCardList), findsOneWidget);
    gate.complete();
  });

  testWidgets('Failure: an unknown token shows the invalid-link state', (
    tester,
  ) async {
    await _pump(tester, repository: FakePublicMerchantRepository());

    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.text('Este enlace no es válido. Pide uno nuevo al parqueadero.'),
      findsOneWidget,
    );
  });

  testWidgets('Security: a malformed token never calls the backend', (
    tester,
  ) async {
    final repository = FakePublicMerchantRepository(portalResult: samplePortal);
    await _pump(tester, repository: repository, token: 'short');

    expect(repository.portalCalls, 0);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('Success: registering the plate shows the confirmation', (
    tester,
  ) async {
    final repository = FakePublicMerchantRepository(portalResult: samplePortal);
    await _pump(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'ABC123');
    await tester.enterText(find.byKey(const Key('validate_pin')), '123456');
    await tester.tap(find.byKey(const Key('validate_submit')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Convenio registrado'), findsOneWidget);
    expect(find.text('Validar otra placa'), findsOneWidget);
    expect(repository.calls.single.plate, 'ABC123');
  });

  testWidgets('Failure: a wrong PIN shows the attempts left', (tester) async {
    final repository = FakePublicMerchantRepository(
      portalResult: samplePortal,
      result: const ValidationInvalidPin(4),
    );
    await _pump(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'ABC123');
    await tester.enterText(find.byKey(const Key('validate_pin')), '000000');
    await tester.tap(find.byKey(const Key('validate_submit')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('PIN incorrecto. Intentos restantes: 4'),
      findsOneWidget,
    );
  });

  testWidgets('Security: a locked merchant disables the form', (tester) async {
    final repository = FakePublicMerchantRepository(
      portalResult: samplePortal,
      result: ValidationLocked(DateTime(2026, 11, 17, 12, 30)),
    );
    await _pump(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'ABC123');
    await tester.enterText(find.byKey(const Key('validate_pin')), '000000');
    await tester.tap(find.byKey(const Key('validate_submit')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    final pin = tester.widget<TextField>(find.byKey(const Key('validate_pin')));
    expect(pin.enabled, isFalse);
  });

  testWidgets('A11y: the actions meet the 48 dp target', (tester) async {
    await _pump(
      tester,
      repository: FakePublicMerchantRepository(portalResult: samplePortal),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
