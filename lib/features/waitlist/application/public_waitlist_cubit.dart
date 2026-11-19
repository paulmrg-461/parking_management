import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/public_waitlist.dart';
import '../domain/entities/waitlist_entry.dart';
import '../domain/repositories/public_waitlist_repository.dart';

sealed class PublicWaitlistState extends Equatable {
  const PublicWaitlistState();

  @override
  List<Object?> get props => const [];
}

final class PublicWaitlistLoading extends PublicWaitlistState {
  const PublicWaitlistLoading();
}

/// The card is usable: `info` describes the lot, [entry] is the customer's own
/// turn when they joined or looked it up.
final class PublicWaitlistReady extends PublicWaitlistState {
  const PublicWaitlistReady(
    this.info, {
    this.entry,
    this.submitting = false,
    this.actionFailure,
    this.claimed,
  });

  final PublicWaitlistInfo info;
  final PublicWaitlistEntry? entry;
  final bool submitting;

  /// The last action failed; the form keeps its data.
  final Failure? actionFailure;

  /// The hold the customer got when the offer was claimed.
  final PublicReservation? claimed;

  PublicWaitlistReady copyWith({
    PublicWaitlistEntry? entry,
    bool? submitting,
    Failure? actionFailure,
    bool clearError = false,
    PublicReservation? claimed,
    bool clearClaimed = false,
  }) => PublicWaitlistReady(
    info,
    entry: entry ?? this.entry,
    submitting: submitting ?? this.submitting,
    actionFailure: clearError ? null : (actionFailure ?? this.actionFailure),
    claimed: clearClaimed ? null : (claimed ?? this.claimed),
  );

  @override
  List<Object?> get props => [info, entry, submitting, actionFailure, claimed];
}

/// The waitlist is off for this lot (or the lot has no row): render nothing.
final class PublicWaitlistUnavailable extends PublicWaitlistState {
  const PublicWaitlistUnavailable();
}

final class PublicWaitlistFailure extends PublicWaitlistState {
  const PublicWaitlistFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// The public card: join, follow the turn, claim the offer or leave.
class PublicWaitlistCubit extends ResilientCubit<PublicWaitlistState> {
  PublicWaitlistCubit(
    this._repository, {
    this.pollInterval = const Duration(seconds: 30),
  }) : super(const PublicWaitlistLoading());

  final PublicWaitlistRepository _repository;

  /// How often a waiting turn is refreshed while the page stays open.
  final Duration pollInterval;

  Timer? _poll;
  int? _lotId;
  String? _phone;
  int? _entryId;

  /// The mobile the customer typed (kept so claim/leave need no retyping).
  String? get phone => _phone;

  /// Code shown on the page, for the deep link and the desk.
  int? get entryId => _entryId;

  Future<void> load(int lotId) async {
    _lotId = lotId;
    emit(const PublicWaitlistLoading());
    try {
      final info = await _repository.info(lotId);
      if (info == null || !info.enabled) {
        _stopPolling();
        emit(const PublicWaitlistUnavailable());
        return;
      }
      emit(PublicWaitlistReady(info));
      _syncPolling();
    } on Failure catch (failure) {
      emit(PublicWaitlistFailure(failure));
    }
  }

  Future<void> join({
    required String plate,
    required int categoryId,
    required DateTime waitUntil,
    required int holdMinutes,
    required String phone,
    required String name,
    String? captchaToken,
  }) async {
    final current = state;
    if (current is! PublicWaitlistReady || _lotId == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      final entry = await _repository.join(
        lotId: _lotId!,
        plate: plate,
        categoryId: categoryId,
        waitUntil: waitUntil,
        holdMinutes: holdMinutes,
        phone: phone,
        name: name,
        captchaToken: captchaToken,
      );
      _phone = phone;
      _entryId = entry.id;
      emit(current.copyWith(entry: entry, submitting: false));
      _syncPolling();
    } on Failure catch (failure) {
      // A refused join never stores an entry: the form stays as it was.
      emit(current.copyWith(submitting: false, actionFailure: failure));
    }
  }

  /// Finds the customer's turn with the code and the mobile.
  Future<void> lookup(int entryId, String phone) async {
    final current = state;
    if (current is! PublicWaitlistReady || _lotId == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      final entry = await _repository.lookup(
        lotId: _lotId!,
        entryId: entryId,
        phone: phone,
      );
      if (entry == null) {
        emit(
          current.copyWith(
            submitting: false,
            actionFailure: const ValidationFailure(
              'WaitlistEntryNotFoundError',
              'WaitlistEntryNotFoundError',
            ),
          ),
        );
        return;
      }
      _phone = phone;
      _entryId = entry.id;
      emit(current.copyWith(entry: entry, submitting: false));
      _syncPolling();
    } on Failure catch (failure) {
      emit(current.copyWith(submitting: false, actionFailure: failure));
    }
  }

  Future<void> claim() async {
    final current = state;
    final entry = current is PublicWaitlistReady ? current.entry : null;
    if (current is! PublicWaitlistReady ||
        entry == null ||
        _lotId == null ||
        _phone == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      final reservation = await _repository.claim(
        lotId: _lotId!,
        entryId: entry.id,
        phone: _phone!,
      );
      emit(
        current.copyWith(
          submitting: false,
          claimed: reservation,
          entry: entryStatus(entry, WaitlistStatus.claimed),
        ),
      );
      _syncPolling();
    } on Failure catch (failure) {
      emit(current.copyWith(submitting: false, actionFailure: failure));
      await poll();
    }
  }

  Future<void> leave() async {
    final current = state;
    final entry = current is PublicWaitlistReady ? current.entry : null;
    if (current is! PublicWaitlistReady ||
        entry == null ||
        _lotId == null ||
        _phone == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearError: true));
    try {
      await _repository.leave(
        lotId: _lotId!,
        entryId: entry.id,
        phone: _phone!,
      );
      emit(
        current.copyWith(
          submitting: false,
          entry: entryStatus(entry, WaitlistStatus.left),
          clearClaimed: true,
        ),
      );
      _syncPolling();
    } on Failure catch (failure) {
      emit(current.copyWith(submitting: false, actionFailure: failure));
    }
  }

  /// Refreshes the turn on screen: an offer appears, an expired turn closes.
  Future<void> poll() async {
    final current = state;
    final entry = current is PublicWaitlistReady ? current.entry : null;
    if (current is! PublicWaitlistReady ||
        entry == null ||
        _lotId == null ||
        _phone == null) {
      return;
    }
    try {
      final fresh = await _repository.lookup(
        lotId: _lotId!,
        entryId: entry.id,
        phone: _phone!,
      );
      if (fresh != null && !isClosed) {
        emit(current.copyWith(entry: fresh));
        _syncPolling();
      }
    } on Failure {
      // A poll is best effort: the buttons keep working.
    }
  }

  /// Polls while a waiting or offered turn is on screen.
  void _syncPolling() {
    final current = state;
    final entry = current is PublicWaitlistReady ? current.entry : null;
    final open = entry != null && !entry.isFinished && !entry.isClaimed;
    if (open && _poll == null) {
      _poll = Timer.periodic(pollInterval, (_) => poll());
      return;
    }
    if (!open) {
      _stopPolling();
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  Future<void> close() async {
    _stopPolling();
    return super.close();
  }
}

/// A copy of [entry] with another status (the local answer while the poll
/// catches up).
PublicWaitlistEntry entryStatus(
  PublicWaitlistEntry entry,
  WaitlistStatus status,
) => PublicWaitlistEntry(
  id: entry.id,
  plate: entry.plate,
  categoryId: entry.categoryId,
  categoryName: entry.categoryName,
  status: status,
  position: entry.position,
  waitUntil: entry.waitUntil,
  holdMinutes: entry.holdMinutes,
  claimMinutes: entry.claimMinutes,
  notifyChannel: entry.notifyChannel,
  offerUntil: entry.offerUntil,
  reservationId: entry.reservationId,
  lotName: entry.lotName,
  address: entry.address,
  phone: entry.phone,
  whatsapp: entry.whatsapp,
);
