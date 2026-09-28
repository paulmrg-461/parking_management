import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/repositories/monthly_pass_repository.dart';

sealed class MonthlyPassesState extends Equatable {
  const MonthlyPassesState();

  @override
  List<Object?> get props => const [];
}

final class MonthlyPassesInitial extends MonthlyPassesState {
  const MonthlyPassesInitial();
}

final class MonthlyPassesLoading extends MonthlyPassesState {
  const MonthlyPassesLoading();
}

/// Passes plus the vehicles for the create form and a precomputed
/// vehicleId → plate map (O(1) per row).
final class MonthlyPassesLoaded extends MonthlyPassesState {
  const MonthlyPassesLoaded({
    required this.monthlyPasses,
    this.vehicles = const [],
    this.plates = const {},
    this.submission = const SubmissionIdle(),
  });

  final List<MonthlyPass> monthlyPasses;
  final List<Vehicle> vehicles;
  final Map<int, String> plates;
  final Submission submission;

  String plateOf(MonthlyPass pass) =>
      plates[pass.vehicleId] ?? 'Vehicle ${pass.vehicleId}';

  MonthlyPassesLoaded copyWith({
    List<MonthlyPass>? monthlyPasses,
    Submission? submission,
  }) => MonthlyPassesLoaded(
    monthlyPasses: monthlyPasses ?? this.monthlyPasses,
    vehicles: vehicles,
    plates: plates,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [monthlyPasses, vehicles, plates, submission];
}

/// The list itself could not be loaded (action errors never land here).
final class MonthlyPassesFailure extends MonthlyPassesState {
  const MonthlyPassesFailure(this.message, {this.failure});

  MonthlyPassesFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class MonthlyPassesCubit extends Cubit<MonthlyPassesState> {
  MonthlyPassesCubit(this._repository, this._vehicles)
    : super(const MonthlyPassesInitial());

  final MonthlyPassRepository _repository;
  final VehicleRepository _vehicles;

  Future<void> load({int? vehicleId}) async {
    emit(const MonthlyPassesLoading());
    final vehicles = _loadVehicles();
    try {
      final passes = await _repository.list(vehicleId: vehicleId);
      final loadedVehicles = await vehicles;
      emit(
        MonthlyPassesLoaded(
          monthlyPasses: passes,
          vehicles: loadedVehicles,
          plates: {
            for (final vehicle in loadedVehicles)
              if (vehicle.id != null) vehicle.id!: vehicle.plate,
          },
        ),
      );
    } on Failure catch (failure) {
      vehicles.ignore();
      emit(MonthlyPassesFailure.of(failure));
    }
  }

  Future<void> create(CreateMonthlyPassCommand command) =>
      _submit(() => _repository.create(command));

  Future<void> update(UpdateMonthlyPassCommand command) =>
      _submit(() => _repository.update(command));

  Future<void> delete(int id) => _submit(() => _repository.delete(id));

  Future<void> _submit(Future<Object?> Function() action) async {
    final current = state;
    if (current is! MonthlyPassesLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await action();
      emit(
        current.copyWith(
          monthlyPasses: await _repository.list(),
          submission: const SubmissionIdle(),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  /// Best-effort: without vehicles rows fall back to `Vehicle <id>`.
  Future<List<Vehicle>> _loadVehicles() async {
    try {
      return await _vehicles.list();
    } on Failure {
      return const [];
    }
  }
}
