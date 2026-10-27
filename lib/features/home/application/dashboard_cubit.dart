import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../check_out/domain/entities/capacity_snapshot.dart';
import '../../check_out/domain/entities/occupancy_snapshot.dart';
import '../../check_out/domain/entities/open_session.dart';
import '../../check_out/domain/entities/today_summary.dart';
import '../../check_out/domain/repositories/check_out_repository.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
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
    this.capacity = CapacitySnapshot.empty,
    this.sessions = const [],
    this.plates = const {},
  });

  /// Vehicles currently inside (open sessions).
  final int openSessions;
  final int totalCapacity;
  final List<CategoryOccupancySnapshot> categories;
  final TodaySummary today;

  /// Space configuration (cars/pickups, motorcycles, keys) vs. what is inside.
  final CapacitySnapshot capacity;

  /// First open sessions for the home list, with their plates.
  final List<OpenSession> sessions;
  final Map<int, String> plates;

  bool get isFull => totalCapacity > 0 && openSessions >= totalCapacity;

  String plateOf(OpenSession session) =>
      plates[session.vehicleId] ?? 'Vehicle #${session.vehicleId}';

  @override
  List<Object?> get props =>
      [openSessions, totalCapacity, categories, today, capacity, sessions, plates];
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Operator/admin home summary: current occupancy. Asks for a single row
/// and reads the count from `X-Total-Count`, so it stays cheap.
class DashboardCubit extends ResilientCubit<DashboardState> {
  DashboardCubit(this._sessions, [this._vehicles])
    : super(const DashboardLoading());

  final CheckOutRepository _sessions;

  /// Optional: resolves the plates of the "inside" list.
  final VehicleRepository? _vehicles;

  Future<void> load() async {
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }
    try {
      final snapshot = await _sessions.occupancy();
      // The summary is a nice-to-have: a failure keeps zeros, not an error.
      final today = await _sessions
          .todaySummary()
          .catchError((Object _) => TodaySummary.empty);
      final capacity = await _sessions
          .capacitySnapshot()
          .catchError((Object _) => CapacitySnapshot.empty);
      final inside = await _inside();
      _emit(
        DashboardLoaded(
          openSessions: snapshot.totalOpen,
          totalCapacity: snapshot.totalCapacity,
          categories: snapshot.byCategory,
          today: today,
          capacity: capacity,
          sessions: inside.sessions,
          plates: inside.plates,
        ),
      );
    } on Failure catch (failure) {
      if (state is! DashboardLoaded) {
        _emit(DashboardFailure(failure));
      }
    }
  }

  /// First page of cars inside + the plate map; a failure keeps the home
  /// useful with the counters only.
  Future<({List<OpenSession> sessions, Map<int, String> plates})> _inside() async {
    try {
      final page = await _sessions.listOpenSessions(offset: 0, limit: 5);
      final vehicles = _vehicles;
      if (vehicles == null || page.items.isEmpty) {
        return (sessions: page.items, plates: const <int, String>{});
      }
      final vehiclePage = await vehicles.listPage(offset: 0, limit: 100);
      final plates = <int, String>{
        for (final Vehicle vehicle in vehiclePage.items)
          if (vehicle.id != null) vehicle.id!: vehicle.plate,
      };
      return (sessions: page.items, plates: plates);
    } catch (_) {
      return (
        sessions: const <OpenSession>[],
        plates: const <int, String>{},
      );
    }
  }

  void _emit(DashboardState next) {
    if (!isClosed) {
      emit(next);
    }
  }
}
