import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../plate_scanning/domain/normalize_plate.dart';
import '../domain/entities/parking_session.dart';
import '../domain/repositories/check_in_repository.dart';

sealed class CheckInState extends Equatable {
  const CheckInState();

  @override
  List<Object?> get props => const [];
}

class CheckInInitial extends CheckInState {
  const CheckInInitial();
}

class CheckInLoading extends CheckInState {
  const CheckInLoading();
}

class CheckInLoaded extends CheckInState {
  const CheckInLoaded(this.sessions);

  final List<ParkingSession> sessions;

  @override
  List<Object?> get props => [sessions];
}

class CheckInSubmitting extends CheckInState {
  const CheckInSubmitting();
}

class CheckInSuccess extends CheckInState {
  const CheckInSuccess(this.session);

  final ParkingSession session;

  @override
  List<Object?> get props => [session];
}

class CheckInFailure extends CheckInState {
  const CheckInFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Orchestrates the check-in flow: validates/normalizes the plate, submits it
/// (with any evidence photos) to open a new parking session, and loads the
/// list of currently open sessions.
class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit(this._repository) : super(const CheckInInitial());

  final CheckInRepository _repository;

  Future<void> loadOpenSessions() async {
    emit(const CheckInLoading());
    try {
      emit(CheckInLoaded(await _repository.listOpenSessions()));
    } on Failure catch (failure) {
      emit(CheckInFailure(failure.message));
    }
  }

  /// Submits a check-in for [plate] with optional evidence [photos].
  ///
  /// The plate is normalized/validated client-side first (via
  /// [normalizePlate]); an empty/whitespace-only plate is rejected with a
  /// [CheckInFailure] before the repository is ever called.
  Future<void> submitCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    emit(const CheckInSubmitting());
    try {
      final normalizedPlate = normalizePlate(plate);
      final session = await _repository.createCheckIn(
        plate: normalizedPlate,
        photos: photos,
      );
      emit(CheckInSuccess(session));
    } on Failure catch (failure) {
      emit(CheckInFailure(failure.message));
    }
  }
}
