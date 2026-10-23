import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/lot/lot_context.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/parking_lot.dart';
import '../domain/repositories/lots_repository.dart';

sealed class LotsState extends Equatable {
  const LotsState();

  @override
  List<Object?> get props => const [];
}

final class LotsInitial extends LotsState {
  const LotsInitial();
}

final class LotsLoading extends LotsState {
  const LotsLoading();
}

final class LotsLoaded extends LotsState {
  const LotsLoaded(
    this.lots, {
    this.activeId,
    this.submission = const SubmissionIdle(),
  });

  final List<ParkingLot> lots;
  final int? activeId;
  final Submission submission;

  bool get canSwitch => lots.length > 1;

  ParkingLot? get active {
    for (final lot in lots) {
      if (lot.id == activeId) {
        return lot;
      }
    }
    return lots.isEmpty ? null : lots.first;
  }

  LotsLoaded copyWith({
    List<ParkingLot>? lots,
    int? activeId,
    Submission? submission,
  }) => LotsLoaded(
    lots ?? this.lots,
    activeId: activeId ?? this.activeId,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [lots, activeId, submission];
}

final class LotsFailure extends LotsState {
  const LotsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// App-scoped: resolves the lots of the signed-in user, keeps the active lot
/// (persisted) and creates lots for platform admins.
class LotsCubit extends ResilientCubit<LotsState> {
  LotsCubit(this._repository, this._context) : super(const LotsInitial());

  final LotsRepository _repository;
  final LotContext _context;

  Future<void> load() async {
    final restored = _context.restore();
    if (state is! LotsLoaded) {
      emit(const LotsLoading());
    }
    try {
      final lots = await _repository.myLots();
      final activeId = _resolveActive(lots, restored);
      await _context.select(activeId);
      emit(LotsLoaded(lots, activeId: activeId));
    } on Failure catch (failure) {
      emit(LotsFailure(failure.message));
    }
  }

  int? _resolveActive(List<ParkingLot> lots, int? restored) {
    if (lots.isEmpty) {
      return null;
    }
    final match = lots.where((lot) => lot.id == restored);
    return match.isNotEmpty ? restored : lots.first.id;
  }

  Future<void> select(int lotId) async {
    final current = state;
    if (current is! LotsLoaded) {
      return;
    }
    await _context.select(lotId);
    emit(current.copyWith(activeId: lotId));
  }

  Future<void> create({
    required String code,
    required String name,
    String address = '',
  }) async {
    final current = state;
    if (current is! LotsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final lot = await _repository.create(
        code: code,
        name: name,
        address: address,
      );
      emit(current.copyWith(
        lots: [...current.lots, lot],
        submission: const SubmissionSucceeded<ParkingLot?>(null),
      ));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> setActiveFlag(ParkingLot lot, bool active) async {
    final current = state;
    if (current is! LotsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final updated = await _repository.update(id: lot.id, active: active);
      emit(current.copyWith(
        lots: [
          for (final item in current.lots)
            item.id == updated.id ? updated : item,
        ],
        submission: const SubmissionSucceeded<ParkingLot?>(null),
      ));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }
}
