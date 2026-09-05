import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/commands/create_vehicle_command.dart';
import '../domain/commands/update_vehicle_command.dart';
import '../domain/entities/vehicle.dart';
import '../domain/repositories/vehicle_repository.dart';

sealed class VehiclesState extends Equatable {
  const VehiclesState();

  @override
  List<Object?> get props => const [];
}

class VehiclesInitial extends VehiclesState {
  const VehiclesInitial();
}

class VehiclesLoading extends VehiclesState {
  const VehiclesLoading();
}

class VehiclesLoaded extends VehiclesState {
  const VehiclesLoaded(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  List<Object?> get props => [vehicles];
}

class VehiclesFailure extends VehiclesState {
  const VehiclesFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class VehiclesCubit extends Cubit<VehiclesState> {
  VehiclesCubit(this._repository) : super(const VehiclesInitial());

  final VehicleRepository _repository;

  Future<void> load() async {
    emit(const VehiclesLoading());
    try {
      emit(VehiclesLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(VehiclesFailure(failure.message));
    }
  }

  Future<void> create(CreateVehicleCommand command) async {
    await _run(() => _repository.create(command));
  }

  Future<void> update(UpdateVehicleCommand command) async {
    await _run(() => _repository.update(command));
  }

  Future<void> delete(int id) async {
    await _run(() => _repository.delete(id));
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await load();
    } on Failure catch (failure) {
      emit(VehiclesFailure(failure.message));
    }
  }
}
