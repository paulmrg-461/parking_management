import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../plate_scanning/domain/normalize_plate.dart';
import '../domain/entities/vehicle_history.dart';
import '../domain/repositories/vehicle_history_repository.dart';

enum VehicleHistoryStatus { initial, loading, loaded, failure }

class VehicleHistoryState extends Equatable {
  const VehicleHistoryState({
    this.status = VehicleHistoryStatus.initial,
    this.history,
    this.failure,
  });

  final VehicleHistoryStatus status;
  final VehicleHistory? history;
  final Failure? failure;

  @override
  List<Object?> get props => [status, history, failure];
}

class VehicleHistoryCubit extends ResilientCubit<VehicleHistoryState> {
  VehicleHistoryCubit(this._repository)
    : super(const VehicleHistoryState());

  final VehicleHistoryRepository _repository;

  Future<void> search(String rawPlate) async {
    final String plate;
    try {
      plate = normalizePlate(rawPlate);
    } on Failure catch (failure) {
      emit(VehicleHistoryState(
        status: VehicleHistoryStatus.failure,
        history: state.history,
        failure: failure,
      ));
      return;
    }
    emit(VehicleHistoryState(
      status: VehicleHistoryStatus.loading,
      history: state.history,
    ));
    try {
      final history = await _repository.lookup(plate);
      emit(VehicleHistoryState(
        status: VehicleHistoryStatus.loaded,
        history: history,
      ));
    } on Failure catch (failure) {
      emit(VehicleHistoryState(
        status: VehicleHistoryStatus.failure,
        history: state.history,
        failure: failure,
      ));
    }
  }

  void clear() => emit(const VehicleHistoryState());
}
