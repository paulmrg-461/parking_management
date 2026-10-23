import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../check_out/domain/entities/occupancy_snapshot.dart';
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
  });

  /// Vehicles currently inside (open sessions).
  final int openSessions;
  final int totalCapacity;
  final List<CategoryOccupancySnapshot> categories;

  bool get isFull => totalCapacity > 0 && openSessions >= totalCapacity;

  @override
  List<Object?> get props => [openSessions, totalCapacity, categories];
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
  DashboardCubit(this._sessions) : super(const DashboardLoading());

  final CheckOutRepository _sessions;

  Future<void> load() async {
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }
    try {
      final snapshot = await _sessions.occupancy();
      _emit(
        DashboardLoaded(
          openSessions: snapshot.totalOpen,
          totalCapacity: snapshot.totalCapacity,
          categories: snapshot.byCategory,
        ),
      );
    } on Failure catch (failure) {
      if (state is! DashboardLoaded) {
        _emit(DashboardFailure(failure));
      }
    }
  }

  void _emit(DashboardState next) {
    if (!isClosed) {
      emit(next);
    }
  }
}
