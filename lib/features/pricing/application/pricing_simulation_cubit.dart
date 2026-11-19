import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/pricing_rule.dart';
import '../domain/entities/pricing_simulation.dart';
import '../domain/repositories/pricing_repository.dart';

sealed class PricingSimulationState extends Equatable {
  const PricingSimulationState();

  @override
  List<Object?> get props => const [];
}

final class SimulationIdle extends PricingSimulationState {
  const SimulationIdle();
}

final class SimulationRunning extends PricingSimulationState {
  const SimulationRunning();
}

final class SimulationDone extends PricingSimulationState {
  const SimulationDone(this.result);

  final PricingSimulation result;

  @override
  List<Object?> get props => [result];
}

final class SimulationFailure extends PricingSimulationState {
  const SimulationFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

class PricingSimulationCubit extends ResilientCubit<PricingSimulationState> {
  PricingSimulationCubit(this._repository)
    : super(const SimulationIdle());

  final PricingRepository _repository;
  int _days = 30;
  List<PricingRuleDraft>? _candidates;

  Future<void> run({
    required int days,
    List<PricingRuleDraft>? candidates,
  }) async {
    _days = days;
    _candidates = candidates;
    emit(const SimulationRunning());
    try {
      emit(
        SimulationDone(
          await _repository.simulate(days: days, candidates: candidates),
        ),
      );
    } on Failure catch (failure) {
      emit(SimulationFailure(failure));
    }
  }

  Future<void> retry() => run(days: _days, candidates: _candidates);
}
