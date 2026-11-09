import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../check_out/domain/entities/capacity_snapshot.dart';
import '../../check_out/domain/entities/dashboard_trend.dart';
import '../../check_out/domain/entities/occupancy_snapshot.dart';
import '../../check_out/domain/entities/check_out_preview.dart';
import '../../check_out/domain/entities/open_session.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../../check_out/domain/entities/today_summary.dart';
import '../../check_out/domain/repositories/check_out_repository.dart';
import '../../../core/state/resilient_cubit.dart';

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

  bool get isFull => totalCapacity > 0 && openSessions >= totalCapacity;

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
/// for the previous lot is dropped, and a failure right after a lot switch
/// reports the failure instead of keeping the other lot's numbers.
class DashboardCubit extends ResilientCubit<DashboardState> {
  DashboardCubit(this._sessions, [this._activeLot])
    : super(const DashboardLoading());

  final CheckOutRepository _sessions;

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
      final loaded = await _fetch();
      if (token == _loadSeq) {
        _loadedLot = lot;
        _emit(loaded);
      }
    } on Failure catch (failure) {
      if (token == _loadSeq && !sameLot) {
        _emit(DashboardFailure(failure));
      }
    }
  }

  Future<DashboardLoaded> _fetch() async {
    final snapshot = await _sessions.occupancy();
    // The extras are independent and nice-to-have: run them together and
    // degrade each failure on its own (a slow/cold endpoint must not serialize
    // the whole dashboard).
    final (today, trend, capacity, slotBoard, inside) = await (
      _sessions.todaySummary().catchError((Object _) => TodaySummary.empty),
      _sessions
          .dashboardTrend(days: 14)
          .catchError((Object _) => DashboardTrend.empty),
      _sessions.capacitySnapshot().catchError(
        (Object _) => CapacitySnapshot.empty,
      ),
      _sessions.slotBoard().catchError((Object _) => SlotBoard.empty),
      _inside(),
    ).wait;
    return DashboardLoaded(
      openSessions: snapshot.totalOpen,
      totalCapacity: snapshot.totalCapacity,
      categories: snapshot.byCategory,
      today: today,
      trend: trend,
      capacity: capacity,
      sessions: inside,
      slotBoard: slotBoard,
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
