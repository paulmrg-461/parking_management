import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pricing/application/pricing_simulation_cubit.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_simulation.dart';

import '../../../helpers/fake_pricing_repository.dart';

void main() {
  test('Success: run emits running then done', () async {
    final cubit = PricingSimulationCubit(FakePricingRepository());
    final states = <PricingSimulationState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.run(days: 30);
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<SimulationRunning>());
    expect(cubit.state, isA<SimulationDone>());
    expect(
      (cubit.state as SimulationDone).result.sessionsAffected,
      4,
    );
    await subscription.cancel();
    await cubit.close();
  });

  test('Success: an empty result is done', () async {
    final cubit = PricingSimulationCubit(
      FakePricingRepository(
        simulation: const PricingSimulation(days: 7),
      ),
    );
    await cubit.run(days: 7);
    expect((cubit.state as SimulationDone).result.isEmpty, isTrue);
    await cubit.close();
  });

  test('Failure: an oversized simulation reports its code', () async {
    final cubit = PricingSimulationCubit(
      FakePricingRepository()
        ..writeError = const ValidationFailure(
          'PricingSimulationTooLargeError',
          'PricingSimulationTooLargeError',
        ),
    );
    await cubit.run(days: 90);
    expect(cubit.state, isA<SimulationFailure>());
    expect(
      (cubit.state as SimulationFailure).failure.code,
      'PricingSimulationTooLargeError',
    );
    await cubit.close();
  });
}
