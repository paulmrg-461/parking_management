import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/domain/repositories/category_repository.dart';
import '../../plate_scanning/domain/normalize_plate.dart';
import '../domain/entities/reservation.dart';
import '../domain/repositories/reservation_repository.dart';

/// What the last successful action did, so the page can confirm it.
enum ReservationsAction { created, cancelled }

sealed class ReservationsState extends Equatable {
  const ReservationsState();

  @override
  List<Object?> get props => const [];
}

final class ReservationsInitial extends ReservationsState {
  const ReservationsInitial();
}

final class ReservationsLoading extends ReservationsState {
  const ReservationsLoading();
}

final class ReservationsLoaded extends ReservationsState {
  const ReservationsLoaded(
    this.reservations, {
    this.categories = const [],
    this.submission = const SubmissionIdle(),
    this.lastAction,
  });

  final List<Reservation> reservations;
  final List<Category> categories;
  final Submission submission;
  final ReservationsAction? lastAction;

  ReservationsLoaded copyWith({
    List<Reservation>? reservations,
    List<Category>? categories,
    Submission? submission,
    ReservationsAction? lastAction,
  }) => ReservationsLoaded(
    reservations ?? this.reservations,
    categories: categories ?? this.categories,
    submission: submission ?? this.submission,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [reservations, categories, submission, lastAction];
}

final class ReservationsFailure extends ReservationsState {
  const ReservationsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ReservationsCubit extends ResilientCubit<ReservationsState> {
  ReservationsCubit(this._repository, this._categories)
    : super(const ReservationsInitial());

  final ReservationRepository _repository;
  final CategoryRepository _categories;

  Future<void> load() async {
    if (state is! ReservationsLoaded) {
      emit(const ReservationsLoading());
    }
    try {
      final results = await Future.wait<Object>([
        _repository.listActive(),
        _categories.list(),
      ]);
      emit(
        ReservationsLoaded(
          results[0] as List<Reservation>,
          categories: results[1] as List<Category>,
        ),
      );
    } on Failure catch (failure) {
      emit(ReservationsFailure(failure.message));
    }
  }

  Future<void> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  }) => _submit(
    () => _repository.create(
      plate: normalizePlate(plate),
      categoryId: categoryId,
      until: until,
      notes: notes,
    ),
    ReservationsAction.created,
  );

  Future<void> cancel(int id) =>
      _submit(() => _repository.cancel(id), ReservationsAction.cancelled);

  /// Reports success as soon as the mutation is committed; the list refresh
  /// is separate so its failure keeps the previous list instead of turning
  /// a saved change into an error.
  Future<void> _submit(
    Future<Object?> Function() perform,
    ReservationsAction action,
  ) async {
    final current = state;
    if (current is! ReservationsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await perform();
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
      return;
    }
    emit(
      current.copyWith(
        submission: const SubmissionSucceeded<Object?>(null),
        lastAction: action,
      ),
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final reservations = await _repository.listActive();
      final latest = state;
      if (latest is ReservationsLoaded) {
        emit(latest.copyWith(reservations: reservations));
      }
    } on Failure {
      // Keep the previous list; the next load refreshes it.
    }
  }
}
