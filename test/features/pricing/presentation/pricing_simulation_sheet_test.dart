import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pricing/application/pricing_simulation_cubit.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_simulation.dart';
import 'package:parking_management/features/pricing/presentation/pricing_simulation_sheet.dart';

import '../../../helpers/fake_pricing_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakePricingRepository repository,
) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = PricingSimulationCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BlocProvider<PricingSimulationCubit>.value(
                value: cubit,
                child: const PricingSimulationSheet(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Success: runs and shows the metrics and the rule list', (
    tester,
  ) async {
    final repository = FakePricingRepository();
    await _pump(tester, repository);

    expect(repository.simulationCalls, greaterThanOrEqualTo(1));
    expect(find.text('Cobro simulado'), findsOneWidget);
    expect(find.textContaining('Ultimos 30 dias'), findsWidgets);
  });

  testWidgets('Empty: no sessions shows the empty note', (tester) async {
    await _pump(
      tester,
      FakePricingRepository(simulation: const PricingSimulation(days: 30)),
    );

    expect(
      find.text('No hay entradas cobradas en ese periodo.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: an oversized simulation offers retry', (tester) async {
    await _pump(
      tester,
      FakePricingRepository()
        ..writeError = const ValidationFailure(
          'PricingSimulationTooLargeError',
          'PricingSimulationTooLargeError',
        ),
    );

    expect(find.textContaining('Demasiadas entradas'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
