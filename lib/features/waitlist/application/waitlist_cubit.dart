import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/waitlist_entry.dart';
import '../domain/entities/waitlist_settings.dart';
import '../domain/repositories/waitlist_repository.dart';

sealed class WaitlistState extends Equatable {
  const WaitlistState();

  @override
  List<Object?> get props => const [];
}

final class WaitlistInitial extends WaitlistState {
  const WaitlistInitial();
}

final class WaitlistLoading extends WaitlistState {
  const WaitlistLoading();
}

final class WaitlistLoaded extends WaitlistState {
  const WaitlistLoaded(
    this.entries, {
    this.submission = const SubmissionIdle(),
    this.settings,
  });

  final List<WaitlistEntry> entries;

  /// Action status kept apart from the list: a failing "give the space" never
  /// wipes the rows.
  final Submission submission;
  final WaitlistSettings? settings;

  bool get isEmpty => entries.isEmpty;

  @override
  List<Object?> get props => [entries, submission, settings];
}

final class WaitlistFailure extends WaitlistState {
  const WaitlistFailure(this.message, {this.failure});

  WaitlistFailure.of(Failure failure)
    : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Desk side of the queue: list, give the space, remove, settings.
class WaitlistCubit extends ResilientCubit<WaitlistState> {
  WaitlistCubit(this._repository) : super(const WaitlistInitial());

  final WaitlistRepository _repository;

  Future<void> load() async {
    emit(const WaitlistLoading());
    try {
      final settings = await _repository.loadSettings();
      final entries = await _repository.list();
      emit(WaitlistLoaded(entries, settings: settings));
    } on Failure catch (failure) {
      emit(WaitlistFailure.of(failure));
    }
  }

  /// Gives the offered space to the customer; the board reloads after.
  Future<PublicReservation?> claim(int id) => _submit(() => _repository.claim(id));

  Future<void> remove(int id) => _submit(() => _repository.remove(id));

  Future<void> saveSettings(WaitlistSettings settings) =>
      _submit(() => _repository.saveSettings(settings));

  /// Runs [action] with the list on screen, then reloads on success. A failure
  /// becomes a [SubmissionFailed] instead of replacing the rows.
  Future<T?> _submit<T>(Future<T> Function() action) async {
    final current = state;
    final loaded = current is WaitlistLoaded
        ? current
        : const WaitlistLoaded([]);
    emit(
      WaitlistLoaded(
        loaded.entries,
        submission: const SubmissionInProgress(),
        settings: loaded.settings,
      ),
    );
    try {
      final result = await action();
      final entries = await _repository.list();
      final settings = await _repository.loadSettings();
      if (!isClosed) {
        emit(
          WaitlistLoaded(
            entries,
            submission: SubmissionSucceeded(result),
            settings: settings,
          ),
        );
      }
      return result;
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          WaitlistLoaded(
            loaded.entries,
            submission: SubmissionFailed.of(failure),
            settings: loaded.settings,
          ),
        );
      }
      return null;
    }
  }
}
