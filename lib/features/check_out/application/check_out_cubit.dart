import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../core/state/submission.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import '../domain/repositories/check_out_repository.dart';
import 'check_out_vehicle.dart';

sealed class CheckOutState extends Equatable {
  const CheckOutState();

  @override
  List<Object?> get props => const [];
}

final class CheckOutInitial extends CheckOutState {
  const CheckOutInitial();
}

final class CheckOutLoading extends CheckOutState {
  const CheckOutLoading();
}

/// Loaded sessions plus everything the page renders, precomputed here:
/// [plates] (vehicleId → plate, O(1) per row) and [visible] (search result).
final class CheckOutLoaded extends CheckOutState {
  const CheckOutLoaded({
    required this.sessions,
    required this.plates,
    this.query = '',
    List<OpenSession>? visible,
    this.total,
    this.loadingMore = false,
    this.submission = const SubmissionIdle(),
  }) : visible = visible ?? sessions;

  final List<OpenSession> sessions;
  final Map<int, String> plates;
  final String query;
  final List<OpenSession> visible;
  final int? total;
  final bool loadingMore;
  final Submission submission;

  bool get hasMore => total != null && total! > sessions.length;

  String plateOf(OpenSession session) =>
      plates[session.vehicleId] ?? 'Vehicle #${session.vehicleId}';

  CheckOutLoaded copyWith({
    List<OpenSession>? sessions,
    String? query,
    int? total,
    bool? loadingMore,
    Submission? submission,
  }) {
    final nextSessions = sessions ?? this.sessions;
    final nextQuery = query ?? this.query;
    return CheckOutLoaded(
      sessions: nextSessions,
      plates: plates,
      query: nextQuery,
      visible: _filter(nextSessions, nextQuery),
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      submission: submission ?? this.submission,
    );
  }

  List<OpenSession> _filter(List<OpenSession> all, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return all;
    }
    return [
      for (final session in all)
        if (plateOf(session).toLowerCase().contains(query)) session,
    ];
  }

  @override
  List<Object?> get props => [
    sessions,
    plates,
    query,
    visible,
    total,
    loadingMore,
    submission,
  ];
}

final class CheckOutFailure extends CheckOutState {
  const CheckOutFailure(this.message, {this.failure});

  CheckOutFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Check-out flow: paginated open sessions with plates resolved once,
/// debounced plate search, and closing a session without ever dropping the
/// list (the outcome is reported through [CheckOutLoaded.submission]).
class CheckOutCubit extends Cubit<CheckOutState> {
  CheckOutCubit(
    this._checkOutVehicle,
    this._repository,
    this._vehicles, {
    this.searchDebounce = const Duration(milliseconds: 300),
    this.pageSize = defaultPageSize,
  }) : super(const CheckOutInitial());

  final CheckOutVehicle _checkOutVehicle;
  final CheckOutRepository _repository;
  final VehicleRepository _vehicles;
  final Duration searchDebounce;
  final int pageSize;
  Timer? _searchTimer;

  Future<void> loadOpenSessions() async {
    emit(const CheckOutLoading());
    final plates = _plates();
    try {
      final page = await _firstPage();
      emit(
        CheckOutLoaded(
          sessions: page.items,
          plates: await plates,
          total: page.total,
        ),
      );
    } on Failure catch (failure) {
      plates.ignore();
      emit(CheckOutFailure.of(failure));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! CheckOutLoaded || !current.hasMore || current.loadingMore) {
      return;
    }
    emit(current.copyWith(loadingMore: true));
    try {
      final page = await _repository.listOpenSessions(
        offset: current.sessions.length,
        limit: pageSize,
      );
      emit(
        _latest(current).copyWith(
          sessions: [...current.sessions, ...page.items],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on Failure catch (failure) {
      emit(
        _latest(current).copyWith(
          loadingMore: false,
          submission: SubmissionFailed.of(failure),
        ),
      );
    }
  }

  /// Filters by plate after [searchDebounce]; typing never rebuilds the
  /// page itself, only the list once the query settles.
  void search(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () => _applySearch(query));
  }

  Future<void> checkOut(int sessionId) async {
    final current = state;
    if (current is! CheckOutLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final receipt = await _checkOutVehicle(sessionId);
      emit(
        _latest(current).copyWith(
          sessions: await _sessionsAfterCheckOut(sessionId),
          submission: SubmissionSucceeded<CheckOutReceipt>(receipt),
        ),
      );
    } on Failure catch (failure) {
      emit(
        _latest(current)
            .copyWith(submission: SubmissionFailed.of(failure)),
      );
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }

  void _applySearch(String query) {
    final current = state;
    if (!isClosed && current is CheckOutLoaded) {
      emit(current.copyWith(query: query));
    }
  }

  CheckOutLoaded _latest(CheckOutLoaded fallback) {
    final current = state;
    return current is CheckOutLoaded ? current : fallback;
  }

  Future<PagedResult<OpenSession>> _firstPage() =>
      _repository.listOpenSessions(offset: 0, limit: pageSize);

  /// Plates are best-effort: a failure falls back to "Vehicle #id" rows.
  Future<Map<int, String>> _plates() async {
    try {
      return _indexPlates(await _vehicles.list());
    } on Failure {
      return const {};
    }
  }

  Map<int, String> _indexPlates(List<Vehicle> vehicles) => {
    for (final vehicle in vehicles)
      if (vehicle.id != null) vehicle.id!: vehicle.plate,
  };

  /// Refetches the first page; offline (queued check-out) the closed session
  /// is simply removed from what is on screen.
  Future<List<OpenSession>> _sessionsAfterCheckOut(int sessionId) async {
    try {
      return (await _firstPage()).items;
    } on Failure {
      final current = state;
      final sessions = current is CheckOutLoaded
          ? current.sessions
          : const <OpenSession>[];
      return [
        for (final s in sessions)
          if (s.id != sessionId) s,
      ];
    }
  }
}
