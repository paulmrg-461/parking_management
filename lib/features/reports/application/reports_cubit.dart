import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import '../domain/repositories/report_repository.dart';
import '../../../core/state/resilient_cubit.dart';

sealed class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => const [];
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  const ReportsLoaded(
    this.revenue,
    this.occupancy, {
    this.allLots = false,
  });

  final RevenueReport revenue;
  final OccupancyReport occupancy;

  /// `true` while the consolidated (every lot) view is selected.
  final bool allLots;

  @override
  List<Object?> get props => [revenue, occupancy, allLots];
}

class ReportsFailure extends ReportsState {
  const ReportsFailure(this.message, {this.failure});

  ReportsFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Orchestrates the admin reports screen: fetches revenue and occupancy for
/// the selected date range and emits both together, so the page never shows
/// one report without the other.
class ReportsCubit extends ResilientCubit<ReportsState> {
  ReportsCubit(this._repository) : super(const ReportsInitial());

  final ReportRepository _repository;

  Future<void> loadReports({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  }) async {
    emit(const ReportsLoading());
    try {
      final results = await Future.wait([
        _repository.getRevenueReport(
          startDate: startDate,
          endDate: endDate,
          allLots: allLots,
        ),
        _repository.getOccupancyReport(),
      ]);
      emit(
        ReportsLoaded(
          results[0] as RevenueReport,
          results[1] as OccupancyReport,
          allLots: allLots,
        ),
      );
    } on Failure catch (failure) {
      emit(ReportsFailure.of(failure));
    }
  }
}
