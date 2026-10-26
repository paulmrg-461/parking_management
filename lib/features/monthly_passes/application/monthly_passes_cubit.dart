import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/entities/monthly_pass_payment.dart';
import '../domain/repositories/monthly_pass_repository.dart';
import '../../../core/state/resilient_cubit.dart';

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

/// What the last successful action did, so the page can confirm it.
enum MonthlyPassAction { created, deleted, payment }

/// Passes plus the vehicles for the create form and a precomputed
/// vehicleId → plate map (O(1) per row).
final class MonthlyPassesLoaded extends MonthlyPassesState {
  const MonthlyPassesLoaded({
    required this.monthlyPasses,
    this.vehicles = const [],
    this.plates = const {},
    this.pendingPayments = const [],
    this.submission = const SubmissionIdle(),
    this.lastAction,
  });

  final List<MonthlyPass> monthlyPasses;
  final List<Vehicle> vehicles;
  final Map<int, String> plates;
  final Submission submission;
  final MonthlyPassAction? lastAction;
  final List<MonthlyPassPayment> pendingPayments;

  String plateOf(MonthlyPass pass) =>
      plates[pass.vehicleId] ?? 'Vehicle ${pass.vehicleId}';

  /// Customer phone of the pass' vehicle, when known.
  String? phoneOf(MonthlyPass pass) {
    for (final vehicle in vehicles) {
      if (vehicle.id == pass.vehicleId) {
        return vehicle.ownerPhone;
      }
    }
    return null;
  }

  MonthlyPassesLoaded copyWith({
    List<MonthlyPass>? monthlyPasses,
    List<MonthlyPassPayment>? pendingPayments,
    Submission? submission,
    MonthlyPassAction? lastAction,
  }) => MonthlyPassesLoaded(
    monthlyPasses: monthlyPasses ?? this.monthlyPasses,
    pendingPayments: pendingPayments ?? this.pendingPayments,
    vehicles: vehicles,
    plates: plates,
    submission: submission ?? this.submission,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [
    monthlyPasses,
    vehicles,
    plates,
    pendingPayments,
    submission,
    lastAction,
  ];
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

class MonthlyPassesCubit extends ResilientCubit<MonthlyPassesState> {
  MonthlyPassesCubit(this._repository, this._vehicles)
    : super(const MonthlyPassesInitial());

  final MonthlyPassRepository _repository;
  final VehicleRepository _vehicles;

  Future<void> load({int? vehicleId}) async {
    emit(const MonthlyPassesLoading());
    final vehicles = _loadVehicles();
    try {
      final passes = await _repository.list(vehicleId: vehicleId);
      final pending = await _repository.pendingPayments();
      final loadedVehicles = await vehicles;
      emit(
        MonthlyPassesLoaded(
          monthlyPasses: sortMonthlyPasses(passes),
          pendingPayments: pending,
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
      _submit(() => _repository.create(command), action: MonthlyPassAction.created);

  Future<void> update(UpdateMonthlyPassCommand command) =>
      _submit(() => _repository.update(command));

  Future<void> delete(int id) =>
      _submit(() => _repository.delete(id), action: MonthlyPassAction.deleted);

  Future<void> registerPayment(int id, String method) =>
      _submit(
        () => _repository.registerPayment(id, method),
        action: MonthlyPassAction.payment,
      );

  Future<void> _submit(
    Future<Object?> Function() perform, {
    MonthlyPassAction? action,
  }) async {
    final current = state;
    if (current is! MonthlyPassesLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final result = await perform();
      emit(
        current.copyWith(
          monthlyPasses: await _repository.list(),
          pendingPayments: await _repository.pendingPayments(),
          submission: action == null
              ? const SubmissionIdle()
              : SubmissionSucceeded<Object?>(result),
          lastAction: action,
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
