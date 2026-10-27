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
  List<Object?> get props => [
    reservations,
    categories,
    submission,
    lastAction,
  ];
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
      final reservations = await _repository.listActive();
      final categories = await _categories.list();
      emit(ReservationsLoaded(reservations, categories: categories));
    } on Failure catch (failure) {
      emit(ReservationsFailure(failure.message));
    }
  }

  Future<void> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  }) async {
    final current = state;
    if (current is! ReservationsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final normalized = normalizePlate(plate);
      await _repository.create(
        plate: normalized,
        categoryId: categoryId,
        until: until,
        notes: notes,
      );
      emit(current.copyWith(
        reservations: await _repository.listActive(),
        submission: const SubmissionSucceeded<Object?>(null),
        lastAction: ReservationsAction.created,
      ));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> cancel(int id) async {
    final current = state;
    if (current is! ReservationsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.cancel(id);
      emit(current.copyWith(
        reservations: await _repository.listActive(),
        submission: const SubmissionSucceeded<Object?>(null),
        lastAction: ReservationsAction.cancelled,
      ));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }
}
