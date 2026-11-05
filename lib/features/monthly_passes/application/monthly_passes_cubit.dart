import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../../tariffs/domain/entities/tariff.dart';
import '../../tariffs/domain/repositories/tariff_repository.dart';
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
enum MonthlyPassAction { created, deleted, payment, renewed }

/// Passes plus the vehicles for the create form and a precomputed
/// vehicleId → plate map (O(1) per row).
final class MonthlyPassesLoaded extends MonthlyPassesState {
  const MonthlyPassesLoaded({
    required this.monthlyPasses,
    this.vehicles = const [],
    this.plates = const {},
    this.pendingPayments = const [],
    this.tariffs = const [],
    this.submission = const SubmissionIdle(),
    this.lastAction,
  });

  final List<MonthlyPass> monthlyPasses;
  final List<Vehicle> vehicles;
  final Map<int, String> plates;
  final Submission submission;
  final MonthlyPassAction? lastAction;
  final List<MonthlyPassPayment> pendingPayments;

  /// Price catalog; the pass dialog prefills the monthly amount from here.
  final List<Tariff> tariffs;

  /// Active monthly tariffs keyed by category, for the pass dialog.
  Map<int, int> get monthlyTariffByCategory => {
    for (final tariff in tariffs)
      if (tariff.active && tariff.type == TariffType.monthly)
        tariff.categoryId: tariff.amount,
  };

  /// Monthly tariff for [categoryId], when configured and active.
  int? monthlyTariffFor(int categoryId) {
    for (final tariff in tariffs) {
      if (tariff.active &&
          tariff.type == TariffType.monthly &&
          tariff.categoryId == categoryId) {
        return tariff.amount;
      }
    }
    return null;
  }

  String plateOf(MonthlyPass pass) =>
      plates[pass.vehicleId] ?? 'Vehicle ${pass.vehicleId}';

  /// Owner name of the pass' vehicle, when known.
  String? ownerNameOf(MonthlyPass pass) {
    for (final vehicle in vehicles) {
      if (vehicle.id == pass.vehicleId) {
        return vehicle.ownerName;
      }
    }
    return null;
  }

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
    List<Tariff>? tariffs,
    Submission? submission,
    MonthlyPassAction? lastAction,
  }) => MonthlyPassesLoaded(
    monthlyPasses: monthlyPasses ?? this.monthlyPasses,
    pendingPayments: pendingPayments ?? this.pendingPayments,
    tariffs: tariffs ?? this.tariffs,
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
    tariffs,
    submission,
    lastAction,
  ];
}

/// The list itself could not be loaded (action errors never land here).
final class MonthlyPassesFailure extends MonthlyPassesState {
  const MonthlyPassesFailure(this.message, {this.failure});

  MonthlyPassesFailure.of(Failure failure)
    : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class MonthlyPassesCubit extends ResilientCubit<MonthlyPassesState> {
  MonthlyPassesCubit(this._repository, this._vehicles, [this._tariffs])
    : super(const MonthlyPassesInitial());

  final MonthlyPassRepository _repository;
  final VehicleRepository _vehicles;
  final TariffRepository? _tariffs;

  Future<void> load({int? vehicleId}) async {
    emit(const MonthlyPassesLoading());
    final vehicles = _loadVehicles();
    final tariffs = _loadTariffs();
    try {
      final passes = await _repository.list(vehicleId: vehicleId);
      final pending = await _repository.pendingPayments();
      final loadedVehicles = await vehicles;
      final loadedTariffs = await tariffs;
      emit(
        MonthlyPassesLoaded(
          monthlyPasses: sortMonthlyPasses(passes),
          pendingPayments: pending,
          tariffs: loadedTariffs,
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

  Future<void> create(CreateMonthlyPassCommand command) => _submit(
    () => _repository.create(command),
    action: MonthlyPassAction.created,
  );

  Future<void> update(UpdateMonthlyPassCommand command) =>
      _submit(() => _repository.update(command));

  /// Manual renewal: continues the day after the current end (or starts today
  /// for an expired pass) for 30 days, keeping the amount.
  Future<void> renew(MonthlyPass pass) async {
    final id = pass.id;
    if (id == null) {
      return;
    }
    final period = pass.renewedPeriod();
    await _submit(
      () => _repository.update(
        UpdateMonthlyPassCommand(
          id: id,
          startDate: period.start,
          endDate: period.end,
        ),
      ),
      action: MonthlyPassAction.renewed,
    );
  }

  Future<void> delete(int id) =>
      _submit(() => _repository.delete(id), action: MonthlyPassAction.deleted);

  Future<void> registerPayment(int id, String method) => _submit(
    () => _repository.registerPayment(id, method),
    action: MonthlyPassAction.payment,
  );

  /// Reports the outcome as soon as the mutation is committed; the list
  /// refresh is separate so its failure can never turn a saved change into
  /// an error (the previous lists stay on screen).
  Future<void> _submit(
    Future<Object?> Function() perform, {
    MonthlyPassAction? action,
  }) async {
    final current = state;
    if (current is! MonthlyPassesLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    final Object? result;
    try {
      result = await perform();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
      return;
    }
    emit(
      current.copyWith(
        submission: action == null
            ? const SubmissionIdle()
            : SubmissionSucceeded<Object?>(result),
        lastAction: action,
      ),
    );
    await _refreshLists();
  }

  Future<void> _refreshLists() async {
    try {
      final passes = await _repository.list();
      final pending = await _repository.pendingPayments();
      final latest = state;
      if (latest is MonthlyPassesLoaded) {
        emit(latest.copyWith(monthlyPasses: passes, pendingPayments: pending));
      }
    } on Failure {
      // Keep the previous lists; the next load refreshes them.
    }
  }

  /// Best-effort: without vehicles rows fall back to `Vehicle <id>`.
  Future<List<Tariff>> _loadTariffs() async {
    try {
      return await _tariffs?.list() ?? const [];
    } on Failure {
      return const [];
    }
  }

  Future<List<Vehicle>> _loadVehicles() async {
    try {
      return await _vehicles.list();
    } on Failure {
      return const [];
    }
  }
}
