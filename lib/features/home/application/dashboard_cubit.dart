import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../check_out/domain/entities/capacity_snapshot.dart';
import '../../check_out/domain/entities/check_out_preview.dart';
import '../../check_out/domain/entities/dashboard_trend.dart';
import '../../check_out/domain/entities/lot_setup_status.dart';
import '../../check_out/domain/entities/occupancy_snapshot.dart';
import '../../check_out/domain/entities/open_session.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../../check_out/domain/entities/today_summary.dart';
import '../../check_out/domain/repositories/check_out_repository.dart';
import '../domain/entities/dashboard_snapshot.dart';
import '../domain/repositories/dashboard_cache.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => const [];
}

final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.openSessions,
    this.totalCapacity = 0,
    this.categories = const [],
    this.today = TodaySummary.empty,
    this.trend = DashboardTrend.empty,
    this.capacity = CapacitySnapshot.empty,
    this.sessions = const [],
    this.slotBoard = SlotBoard.empty,
    this.setup = LotSetupStatus.unknown,
    this.cachedAt,
  });

  /// Vehicles currently inside (open sessions).
  final int openSessions;
  final int totalCapacity;
  final List<CategoryOccupancySnapshot> categories;
  final TodaySummary today;

  /// Daily activity for the last week (empty when the RPC failed).
  final DashboardTrend trend;

  /// Space configuration (cars/pickups, motorcycles, keys) vs. what is inside.
  final CapacitySnapshot capacity;

  /// First open sessions for the home list (each carries its plate).
  final List<OpenSession> sessions;

  /// Visual board (spaces, cars inside, holds).
  final SlotBoard slotBoard;

  /// First-steps checklist of the active site (unknown when it failed).
  final LotSetupStatus setup;

  /// When this came from the offline cache: the state is stale, the board and
  /// the inside list are intentionally empty.
  final DateTime? cachedAt;

  bool get isStale => cachedAt != null;

  bool get isFull => totalCapacity > 0 && openSessions >= totalCapacity;

  /// Only the capacity changes on the hot check-in refresh; everything else
  /// is preserved.
  DashboardLoaded copyWith({CapacitySnapshot? capacity}) => DashboardLoaded(
    openSessions: openSessions,
    totalCapacity: totalCapacity,
    categories: categories,
    today: today,
    trend: trend,
    capacity: capacity ?? this.capacity,
    sessions: sessions,
    slotBoard: slotBoard,
    setup: setup,
    cachedAt: cachedAt,
  );

  String plateOf(OpenSession session) =>
      session.plate.isEmpty ? 'Vehicle #${session.vehicleId}' : session.plate;

  @override
  List<Object?> get props => [
    openSessions,
    totalCapacity,
    categories,
    today,
    trend,
    capacity,
    sessions,
    slotBoard,
    setup,
    cachedAt,
  ];
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Operator/admin home summary: current occupancy. Asks for a single row
/// and reads the count from `X-Total-Count`, so it stays cheap.
///
/// Lot-aware: every [load] takes a sequence token so a slower load started
/// for the previous lot is dropped. A failed load falls back to the cached
/// KPIs of the same lot (marked stale) when there is one.
class DashboardCubit extends ResilientCubit<DashboardState> {
  DashboardCubit(
    this._sessions, {
    this._activeLot,
    this._cache,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const DashboardLoading());

  final CheckOutRepository _sessions;
  final DashboardCache? _cache;
  final DateTime Function() _clock;

  /// Optional: the active lot id, to tell a refresh from a lot switch.
  final int? Function()? _activeLot;
  int _loadSeq = 0;
  int? _loadedLot;

  Future<void> load() async {
    final token = ++_loadSeq;
    final lot = _activeLot?.call();
    final sameLot = state is DashboardLoaded && lot == _loadedLot;
    if (!sameLot) {
      emit(const DashboardLoading());
    }
    try {
      final (loaded, complete) = await _fetch();
      if (token == _loadSeq) {
        _loadedLot = lot;
        _emit(loaded);
        if (complete) {
          unawaited(_writeCache(loaded));
        }
      }
    } on Failure catch (failure) {
      if (token != _loadSeq || sameLot) {
        return;
      }
      final cached = await _readCache();
      if (token != _loadSeq) {
        return;
      }
      if (cached != null) {
        _loadedLot = lot;
        _emit(_fromCache(cached));
      } else {
        _emit(DashboardFailure(failure));
      }
    }
  }

  Future<(DashboardLoaded, bool)> _fetch() async {
    final snapshot = await _sessions.occupancy();
    // The extras are independent and nice-to-have: run them together and
    // degrade each failure on its own (a slow/cold endpoint must not serialize
    // the whole dashboard). `complete` is false when one of the cached KPIs
    // failed, so a degraded load never overwrites a good cached snapshot.
    var complete = true;
    final (today, trend, capacity, slotBoard, inside, setup) = await (
      _sessions.todaySummary().catchError((Object _) {
        complete = false;
        return TodaySummary.empty;
      }),
      _sessions.dashboardTrend(days: 14).catchError((Object _) {
        complete = false;
        return DashboardTrend.empty;
      }),
      _sessions.capacitySnapshot().catchError((Object _) {
        complete = false;
        return CapacitySnapshot.empty;
      }),
      _sessions.slotBoard().catchError((Object _) => SlotBoard.empty),
      _inside(),
      _sessions.lotSetup().catchError((Object _) => LotSetupStatus.unknown),
    ).wait;
    return (
      DashboardLoaded(
        openSessions: snapshot.totalOpen,
        totalCapacity: snapshot.totalCapacity,
        categories: snapshot.byCategory,
        today: today,
        trend: trend,
        capacity: capacity,
        sessions: inside,
        slotBoard: slotBoard,
        setup: setup,
      ),
      complete,
    );
  }

  /// First page of cars inside (plates come with each session); a failure
  /// keeps the home useful with the counters only.
  Future<List<OpenSession>> _inside() async {
    try {
      return (await _sessions.listOpenSessions(offset: 0, limit: 5)).items;
    } catch (_) {
      return const <OpenSession>[];
    }
  }

  Future<void> _writeCache(DashboardLoaded state) async {
    final cache = _cache;
    if (cache == null) {
      return;
    }
    try {
      await cache.write(
        DashboardSnapshot(
          occupancy: OccupancySnapshot(
            totalOpen: state.openSessions,
            totalCapacity: state.totalCapacity,
            byCategory: state.categories,
          ),
          today: state.today,
          trend: state.trend,
          capacity: state.capacity,
          cachedAt: _clock(),
        ),
      );
    } catch (_) {
      // Best effort: a cache write never breaks the dashboard.
    }
  }

  Future<DashboardSnapshot?> _readCache() async {
    final cache = _cache;
    if (cache == null) {
      return null;
    }
    try {
      return await cache.read();
    } catch (_) {
      return null;
    }
  }

  DashboardLoaded _fromCache(DashboardSnapshot snapshot) => DashboardLoaded(
    openSessions: snapshot.occupancy.totalOpen,
    totalCapacity: snapshot.occupancy.totalCapacity,
    categories: snapshot.occupancy.byCategory,
    today: snapshot.today,
    trend: snapshot.trend,
    capacity: snapshot.capacity,
    cachedAt: snapshot.cachedAt,
  );

  /// Refreshes only the space snapshot used by the check-in form, keeping the
  /// rest of the loaded dashboard untouched (one request instead of six).
  Future<void> refreshCapacity() async {
    final current = state;
    if (current is! DashboardLoaded) {
      return;
    }
    try {
      final capacity = await _sessions.capacitySnapshot();
      if (isClosed) {
        return;
      }
      final latest = state;
      if (latest is DashboardLoaded) {
        _emit(latest.copyWith(capacity: capacity));
      }
    } catch (_) {
      // Best effort: the check-in form keeps working with the old snapshot.
    }
  }

  /// Fare estimate for the board sheet (best effort).
  Future<CheckOutPreview?> preview(int sessionId) async {
    try {
      return await _sessions.preview(sessionId);
    } on Failure {
      return null;
    }
  }

  void _emit(DashboardState next) {
    if (!isClosed) {
      emit(next);
    }
  }
}
