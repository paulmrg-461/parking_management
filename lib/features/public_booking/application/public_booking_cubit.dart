import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/public_booking.dart';
import '../domain/phone_rules.dart';
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
    this.cancelling = false,
    this.cancelled = false,
    this.lookupLoading = false,
    this.lookupDone = false,
    this.lookupResult,
    this.lookupFailure,
  });

  final PublicBookingStatus status;
  final PublicBookingAvailability? availability;
  final Failure? failure;
  final bool submitting;

  /// Last confirmed hold; the page renders the confirmation when set.
  final PublicReservation? reservation;

  /// Submit error (form stays visible); separate from the load failure.
  final Failure? actionFailure;

  /// Cancelling the confirmed hold.
  final bool cancelling;

  /// The customer freed the hold; the page thanks them and offers another.
  final bool cancelled;

  /// "Ya reservaste" lookup: searching, the hold found, or why it did not
  /// match (the form stays usable either way).
  final bool lookupLoading;

  /// A lookup finished without finding anything (the "no match" message).
  final bool lookupDone;
  final PublicReservation? lookupResult;
  final Failure? lookupFailure;

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
    bool? cancelling,
    bool? cancelled,
    bool? lookupLoading,
    bool? lookupDone,
    PublicReservation? lookupResult,
    bool clearLookupResult = false,
    Failure? lookupFailure,
    bool clearLookupFailure = false,
  }) => PublicBookingState(
    status: status ?? this.status,
    availability: availability ?? this.availability,
    failure: clearFailure ? null : (failure ?? this.failure),
    submitting: submitting ?? this.submitting,
    reservation: clearReservation ? null : (reservation ?? this.reservation),
    actionFailure: clearActionFailure
        ? null
        : (actionFailure ?? this.actionFailure),
    cancelling: cancelling ?? this.cancelling,
    cancelled: cancelled ?? this.cancelled,
    lookupLoading: lookupLoading ?? this.lookupLoading,
    lookupDone: lookupDone ?? this.lookupDone,
    lookupResult: clearLookupResult
        ? null
        : (lookupResult ?? this.lookupResult),
    lookupFailure: clearLookupFailure
        ? null
        : (lookupFailure ?? this.lookupFailure),
  );

  @override
  List<Object?> get props => [
    status,
    availability,
    failure,
    submitting,
    reservation,
    actionFailure,
    cancelling,
    cancelled,
    lookupLoading,
    lookupDone,
    lookupResult,
    lookupFailure,
  ];
}

/// Public customer booking: availability + one anonymous hold.
class PublicBookingCubit extends ResilientCubit<PublicBookingState> {
  PublicBookingCubit(this._repository) : super(const PublicBookingState());

  final PublicBookingRepository _repository;
  int _lotId = 1;

  /// What the customer already sent, so the hold can be cancelled without
  /// asking again (the RPC needs id + plate + phone).
  String _plate = '';
  String _phone = '';
  String _lookupPhone = '';

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

  /// Re-reads the availability without flashing the skeleton (the page keeps
  /// the current numbers when the call fails).
  Future<void> refresh() async {
    try {
      final availability = await _repository.availability(_lotId);
      if (!isClosed && availability != null) {
        emit(state.copyWith(availability: availability));
      }
    } on Failure {
      // Keep what the customer is looking at.
    }
  }

  Future<void> submit({
    required String plate,
    required int categoryId,
    required int hours,
    required String phone,
    required String name,
    String? captchaToken,
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
        captchaToken: captchaToken,
      );
      if (isClosed) {
        return;
      }
      _plate = plate;
      _phone = phone;
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

  /// Frees the confirmed hold. The RPC needs the code, the plate and the
  /// phone, so a stranger cannot cancel someone else's space.
  Future<void> cancel() async {
    final reservation = state.reservation;
    if (reservation == null) {
      return;
    }
    await _cancel(
      lotId: _lotId,
      reservationId: reservation.id,
      plate: _plate,
      phone: _phone,
    );
  }

  /// Retrieves an active hold with the code on the confirmation plus the
  /// mobile used to book. Null is an answer ("nothing matches"), not an error.
  Future<void> lookup({required int code, required String phone}) async {
    if (state.lookupLoading) {
      return;
    }
    final normalized = normalizeMobilePhone(phone) ?? phone.trim();
    emit(
      state.copyWith(
        lookupLoading: true,
        lookupDone: false,
        clearLookupResult: true,
        clearLookupFailure: true,
      ),
    );
    try {
      final found = await _repository.lookup(
        lotId: _lotId,
        reservationId: code,
        phone: normalized,
      );
      if (isClosed) {
        return;
      }
      _lookupPhone = normalized;
      emit(
        state.copyWith(
          lookupLoading: false,
          lookupDone: true,
          lookupResult: found,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(state.copyWith(lookupLoading: false, lookupFailure: failure));
      }
    }
  }

  /// Cancels the hold retrieved by [lookup] (same guards as the confirmation).
  Future<void> cancelLookup() async {
    final found = state.lookupResult;
    if (found == null) {
      return;
    }
    await _cancel(
      lotId: _lotId,
      reservationId: found.id,
      plate: found.plate,
      phone: _lookupPhone,
    );
  }

  Future<void> _cancel({
    required int lotId,
    required int reservationId,
    required String plate,
    required String phone,
  }) async {
    if (state.cancelling) {
      return;
    }
    emit(state.copyWith(cancelling: true, clearActionFailure: true));
    try {
      await _repository.cancel(
        lotId: lotId,
        reservationId: reservationId,
        plate: plate,
        phone: phone,
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          cancelling: false,
          cancelled: true,
          clearReservation: true,
          clearLookupResult: true,
        ),
      );
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
        emit(state.copyWith(cancelling: false, actionFailure: failure));
      }
    }
  }

  /// Back to the form for a second reservation.
  void reset() {
    emit(
      state.copyWith(
        clearReservation: true,
        clearActionFailure: true,
        cancelled: false,
      ),
    );
  }
}
