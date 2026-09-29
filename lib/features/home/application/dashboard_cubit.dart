import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../check_out/domain/repositories/check_out_repository.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => const [];
}

final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded({required this.openSessions});

  /// Vehicles currently inside (open sessions).
  final int openSessions;

  @override
  List<Object?> get props => [openSessions];
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Operator/admin home summary: current occupancy. Asks for a single row
/// and reads the count from `X-Total-Count`, so it stays cheap.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._sessions) : super(const DashboardLoading());

  final CheckOutRepository _sessions;

  Future<void> load() async {
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }
    try {
      final page = await _sessions.listOpenSessions(limit: 1);
      _emit(DashboardLoaded(openSessions: page.total ?? page.items.length));
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
