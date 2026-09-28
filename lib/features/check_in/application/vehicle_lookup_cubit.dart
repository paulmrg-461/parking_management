import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/domain/repositories/category_repository.dart';
import '../../plate_scanning/domain/normalize_plate.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';

sealed class VehicleLookupState extends Equatable {
  const VehicleLookupState();

  @override
  List<Object?> get props => const [];
}

class VehicleLookupIdle extends VehicleLookupState {
  const VehicleLookupIdle();
}

class VehicleLookupLoading extends VehicleLookupState {
  const VehicleLookupLoading();
}

/// The plate belongs to a registered vehicle. [categoryName] is `null` when
/// the categories could not be resolved (the UI falls back to the id).
class VehicleLookupFound extends VehicleLookupState {
  const VehicleLookupFound(this.vehicle, {this.categoryName});

  final Vehicle vehicle;
  final String? categoryName;

  @override
  List<Object?> get props => [vehicle, categoryName];
}

/// The plate is unknown: [categories] feed the registration form.
class VehicleLookupNotFound extends VehicleLookupState {
  const VehicleLookupNotFound(this.categories);

  final List<Category> categories;

  @override
  List<Object?> get props => [categories];
}

class VehicleLookupFailure extends VehicleLookupState {
  const VehicleLookupFailure(this.message, {this.failure});

  VehicleLookupFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Resolves whether a plate is already registered, so check-in can either
/// show the vehicle read-only or collect the data to register it.
///
/// Every lookup gets a sequence number; results from superseded lookups
/// (typing faster than the network, or [reset]) are dropped.
class VehicleLookupCubit extends Cubit<VehicleLookupState> {
  VehicleLookupCubit(this._vehicles, this._categories)
    : super(const VehicleLookupIdle());

  final VehicleRepository _vehicles;
  final CategoryRepository _categories;
  int _sequence = 0;
  String? _resolvedPlate;

  Future<void> lookup(String rawPlate) async {
    final plate = _normalizeOrNull(rawPlate);
    if (plate == null) {
      reset();
      return;
    }
    if (plate == _resolvedPlate && _isResolved) {
      return;
    }
    final request = ++_sequence;
    _resolvedPlate = plate;
    emit(const VehicleLookupLoading());
    final result = await _resolve(plate);
    if (request == _sequence && !isClosed) {
      emit(result);
    }
  }

  void reset() {
    _sequence++;
    _resolvedPlate = null;
    emit(const VehicleLookupIdle());
  }

  bool get _isResolved =>
      state is VehicleLookupFound || state is VehicleLookupNotFound;

  String? _normalizeOrNull(String rawPlate) {
    try {
      return normalizePlate(rawPlate);
    } on ValidationFailure {
      return null;
    }
  }

  Future<VehicleLookupState> _resolve(String plate) async {
    try {
      final vehicle = await _vehicles.findByPlate(plate);
      if (vehicle != null) {
        return await _found(vehicle);
      }
      return VehicleLookupNotFound(await _categories.list());
    } on Failure catch (failure) {
      return VehicleLookupFailure.of(failure);
    }
  }

  Future<VehicleLookupState> _found(Vehicle vehicle) async {
    try {
      final categories = await _categories.list();
      final match = categories.where((c) => c.id == vehicle.categoryId);
      return VehicleLookupFound(vehicle, categoryName: match.firstOrNull?.name);
    } on Failure {
      return VehicleLookupFound(vehicle);
    }
  }
}
