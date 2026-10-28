import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../domain/entities/parking_spot.dart';
import '../domain/repositories/spot_repository.dart';

enum SpotsStatus { initial, loading, loaded, failure }

class SpotsState extends Equatable {
  const SpotsState({
    this.status = SpotsStatus.initial,
    this.spots = const [],
    this.error,
    this.actionError,
    this.busy = false,
  });

  final SpotsStatus status;
  final List<ParkingSpot> spots;
  final Failure? error;

  /// Last failed write; the UI shows it and the map keeps the old position.
  final Failure? actionError;
  final bool busy;

  SpotsState copyWith({
    SpotsStatus? status,
    List<ParkingSpot>? spots,
    Failure? error,
    Failure? actionError,
    bool? busy,
  }) => SpotsState(
    status: status ?? this.status,
    spots: spots ?? this.spots,
    error: error,
    actionError: actionError,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [status, spots, error, actionError, busy];
}

/// Map editor: the drag & drop layout is saved bay by bay, optimistically.
class SpotsCubit extends ResilientCubit<SpotsState> {
  SpotsCubit(this._repository) : super(const SpotsState());

  final SpotRepository _repository;

  /// Spots configured in Ajustes per group (`0` = no limit); the map may not
  /// differ from this.
  Map<SlotGroup, int> _targets = const {};

  void setTargets(Map<SlotGroup, int> targets) {
    if (mapEquals(_targets, targets)) {
      return;
    }
    _targets = targets;
  }

  int targetOf(SlotGroup group) => _targets[group] ?? 0;

  int drawnOf(SlotGroup group) =>
      state.spots.where((spot) => spot.group == group).length;

  bool canAddTo(SlotGroup group) =>
      targetOf(group) == 0 || drawnOf(group) < targetOf(group);

  bool canRemove(ParkingSpot spot) =>
      targetOf(spot.group) == 0 || drawnOf(spot.group) > targetOf(spot.group);

  Future<void> load() async {
    emit(state.copyWith(status: SpotsStatus.loading, error: null));
    try {
      final spots = await _repository.list();
      emit(
        state.copyWith(status: SpotsStatus.loaded, spots: spots, busy: false),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(status: SpotsStatus.failure, error: failure));
    }
  }

  /// First free grid cell, row-major, leaving the outer ring to grow.
  (int, int) firstFreeCell() {
    final used = {for (final spot in state.spots) (spot.row, spot.col)};
    for (var row = 0; row < 200; row++) {
      for (var col = 0; col < 200; col++) {
        if (!used.contains((row, col))) {
          return (row, col);
        }
      }
    }
    return (0, 0);
  }

  Future<ParkingSpot?> add({
    required String code,
    required SlotGroup group,
    bool active = true,
  }) async {
    if (!canAddTo(group)) {
      emit(
        state.copyWith(
          actionError: const ValidationFailure(
            'All configured spots are already drawn',
            'SpotCapacityReachedError',
          ),
        ),
      );
      return null;
    }
    final (row, col) = firstFreeCell();
    return _write(
      save: () => _repository.save(
        code: code,
        group: group,
        row: row,
        col: col,
        active: active,
      ),
      onSaved: (spot) => state.copyWith(spots: [...state.spots, spot]),
    );
  }

  Future<ParkingSpot?> move(ParkingSpot spot, int row, int col) async {
    if (state.spots.any(
      (other) => other.id != spot.id && other.row == row && other.col == col,
    )) {
      emit(
        state.copyWith(
          actionError: const ValidationFailure(
            'That cell is already taken',
            'spot_cell_taken',
          ),
        ),
      );
      return null;
    }
    final previous = state.spots;
    final moved = spot.copyWith(row: row, col: col);
    emit(state.copyWith(spots: _replace(spot.id, moved), actionError: null));
    try {
      final saved = await _repository.save(
        id: spot.id,
        code: moved.code,
        group: moved.group,
        row: row,
        col: col,
        active: moved.active,
      );
      emit(state.copyWith(spots: _replace(spot.id, saved)));
      return saved;
    } on Failure catch (failure) {
      emit(state.copyWith(spots: previous, actionError: failure));
      return null;
    }
  }

  Future<ParkingSpot?> update(ParkingSpot spot) {
    final previous = state.spots
        .where((item) => item.id == spot.id)
        .map((item) => item.group)
        .firstOrNull;
    if (previous != null &&
        previous != spot.group &&
        !canAddTo(spot.group)) {
      emit(
        state.copyWith(
          actionError: const ValidationFailure(
            'All configured spots are already drawn',
            'SpotCapacityReachedError',
          ),
        ),
      );
      return Future.value();
    }
    return _write(
      save: () => _repository.save(
      id: spot.id,
      code: spot.code,
      group: spot.group,
        row: spot.row,
        col: spot.col,
        active: spot.active,
      ),
      onSaved: (saved) => state.copyWith(spots: _replace(spot.id, saved)),
    );
  }

  Future<bool> remove(ParkingSpot spot) async {
    if (!canRemove(spot)) {
      emit(
        state.copyWith(
          actionError: const ValidationFailure(
            'The map cannot have fewer spots than configured',
            'SpotCapacityRequiredError',
          ),
        ),
      );
      return false;
    }
    final previous = state.spots;
    emit(
      state.copyWith(
        spots: [for (final item in previous) if (item.id != spot.id) item],
        actionError: null,
      ),
    );
    try {
      await _repository.delete(spot.id);
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(spots: previous, actionError: failure));
      return false;
    }
  }

  void clearActionError() => emit(state.copyWith(actionError: null));

  List<ParkingSpot> _replace(int id, ParkingSpot spot) => [
    for (final item in state.spots)
      if (item.id == id) spot else item,
  ];

  Future<ParkingSpot?> _write({
    required Future<ParkingSpot> Function() save,
    required SpotsState Function(ParkingSpot) onSaved,
  }) async {
    emit(state.copyWith(busy: true, actionError: null));
    try {
      final saved = await save();
      emit(onSaved(saved).copyWith(busy: false));
      return saved;
    } on Failure catch (failure) {
      emit(state.copyWith(busy: false, actionError: failure));
      return null;
    }
  }
}
