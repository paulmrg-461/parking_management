import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/public_booking.dart';
import '../domain/repositories/public_booking_repository.dart';

enum PublicBookingStatus { initial, loading, loaded, failure }

class PublicBookingState extends Equatable {
  const PublicBookingState({
    this.status = PublicBookingStatus.initial,
    this.availability,
    this.failure,
    this.submitting = false,
    this.reservation,
    this.actionFailure,
  });

  final PublicBookingStatus status;
  final PublicBookingAvailability? availability;
  final Failure? failure;
  final bool submitting;

  /// Last confirmed hold; the page renders the confirmation when set.
  final PublicReservation? reservation;

  /// Submit error (form stays visible); separate from the load failure.
  final Failure? actionFailure;

  PublicBookingState copyWith({
    PublicBookingStatus? status,
    PublicBookingAvailability? availability,
    Failure? failure,
    bool clearFailure = false,
    bool? submitting,
    PublicReservation? reservation,
    bool clearReservation = false,
    Failure? actionFailure,
    bool clearActionFailure = false,
  }) => PublicBookingState(
    status: status ?? this.status,
    availability: availability ?? this.availability,
    failure: clearFailure ? null : (failure ?? this.failure),
    submitting: submitting ?? this.submitting,
    reservation: clearReservation ? null : (reservation ?? this.reservation),
    actionFailure: clearActionFailure
        ? null
        : (actionFailure ?? this.actionFailure),
  );

  @override
  List<Object?> get props => [
    status,
    availability,
    failure,
    submitting,
    reservation,
    actionFailure,
  ];
}

/// Public customer booking: availability + one anonymous hold.
class PublicBookingCubit extends ResilientCubit<PublicBookingState> {
  PublicBookingCubit(this._repository) : super(const PublicBookingState());

  final PublicBookingRepository _repository;
  int _lotId = 1;

  Future<void> load(int lotId) async {
    _lotId = lotId;
    emit(
      const PublicBookingState().copyWith(status: PublicBookingStatus.loading),
    );
    try {
      final availability = await _repository.availability(lotId);
      if (isClosed) {
        return;
      }
      if (availability == null) {
        emit(
          const PublicBookingState().copyWith(
            status: PublicBookingStatus.failure,
            failure: const ValidationFailure(
              'Parking lot not found',
              'LotNotFoundError',
            ),
          ),
        );
        return;
      }
      emit(
        PublicBookingState(
          status: PublicBookingStatus.loaded,
          availability: availability,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          const PublicBookingState().copyWith(
            status: PublicBookingStatus.failure,
            failure: failure,
          ),
        );
      }
    }
  }

  Future<void> submit({
    required String plate,
    required int categoryId,
    required int hours,
    required String phone,
    required String name,
  }) async {
    if (state.submitting) {
      return;
    }
    emit(state.copyWith(submitting: true, clearActionFailure: true));
    final until = DateTime.now().toUtc().add(Duration(hours: hours));
    try {
      final reservation = await _repository.reserve(
        lotId: _lotId,
        plate: plate,
        categoryId: categoryId,
        until: until,
        phone: phone,
        name: name,
      );
      if (isClosed) {
        return;
      }
      emit(state.copyWith(submitting: false, reservation: reservation));
      // Availability should drop by one; a failure keeps the confirmation.
      try {
        final availability = await _repository.availability(_lotId);
        if (!isClosed && availability != null) {
          emit(state.copyWith(availability: availability));
        }
      } on Failure {
        // Best effort.
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(state.copyWith(submitting: false, actionFailure: failure));
      }
    }
  }

  /// Back to the form for a second reservation.
  void reset() {
    emit(state.copyWith(clearReservation: true, clearActionFailure: true));
  }
}
