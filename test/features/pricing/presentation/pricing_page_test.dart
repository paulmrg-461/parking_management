import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/features/pricing/application/pricing_cubit.dart';
import 'package:parking_management/features/pricing/application/pricing_simulation_cubit.dart';
import 'package:parking_management/features/pricing/presentation/pricing_page.dart';

import '../../../helpers/fake_pricing_repository.dart';
import '../../../helpers/test_app.dart';

Future<PricingCubit> _pump(
  WidgetTester tester,
  FakePricingRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = PricingCubit(repository);
  addTearDown(cubit.close);
  final simulation = PricingSimulationCubit(repository);
  addTearDown(simulation.close);
  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<PricingCubit>.value(value: cubit),
          BlocProvider<PricingSimulationCubit>.value(value: simulation),
        ],
        child: const PricingPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Empty: no rules offers the first one', (tester) async {
    await _pump(tester, FakePricingRepository(rules: []));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Aun no hay reglas'), findsOneWidget);
  });

  testWidgets('Success: lists rules with the summary', (tester) async {
    await _pump(tester, FakePricingRepository());

    expect(find.text('Alta ocupacion'), findsOneWidget);
    expect(find.textContaining('car'), findsWidgets);
    expect(find.textContaining('120 %'), findsOneWidget);
  });

  testWidgets('Success: the settings save the new guard rails', (tester) async {
    final repository = FakePricingRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byKey(const Key('pricing_floor')), '90');
    await tester.enterText(find.byKey(const Key('pricing_ceiling')), '200');
    await tester.enterText(find.byKey(const Key('pricing_round')), '100');
    await tester.tap(find.byKey(const Key('pricing_settings_save')));
    await tester.pumpAndSettle();

    expect(repository.settings.floorBps, 9000);
    expect(repository.settings.ceilingBps, 20000);
    expect(repository.settings.roundTo, 100);
  });

  testWidgets('Failure: an out-of-range floor shows an inline error', (
    tester,
  ) async {
    final repository = FakePricingRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byKey(const Key('pricing_floor')), '5');
    await tester.tap(find.byKey(const Key('pricing_settings_save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('fuera de rango'), findsOneWidget);
    expect(repository.settingsSaves, 0);
  });

  testWidgets('Success: the switch toggles a rule', (tester) async {
    final repository = FakePricingRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('pricing_rule_toggle_1')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.active, isFalse);
  });

  testWidgets('Failure: a failed load offers Retry', (tester) async {
    await _pump(
      tester,
      FakePricingRepository()..loadError = const NetworkFailure('offline'),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('A11y: the page meets the tap target and label guidelines', (
    tester,
  ) async {
    await _pump(tester, FakePricingRepository());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
