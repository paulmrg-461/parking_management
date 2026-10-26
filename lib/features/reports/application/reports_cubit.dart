import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import '../domain/entities/whatsapp_report.dart';
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
    this.whatsapp = WhatsappReport.empty,
    this.allLots = false,
    this.previousTotal,
    this.previousStart,
    this.previousEnd,
  });

  final RevenueReport revenue;
  final OccupancyReport occupancy;
  final WhatsappReport whatsapp;

  /// `true` while the consolidated (every lot) view is selected.
  final bool allLots;

  /// Revenue of the equally long window right before the selected one, when it
  /// could be loaded (`null` otherwise).
  final int? previousTotal;
  final DateTime? previousStart;
  final DateTime? previousEnd;

  int? get deltaPercent {
    final previous = previousTotal;
    if (previous == null || previous == 0) {
      return null;
    }
    return ((revenue.total - previous) * 100 / previous).round();
  }

  @override
  List<Object?> get props => [
    revenue,
    occupancy,
    whatsapp,
    allLots,
    previousTotal,
    previousStart,
    previousEnd,
  ];
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
    final days = endDate.difference(startDate).inDays + 1;
    final previousEnd = startDate.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: days - 1));
    try {
      final results = await Future.wait([
        _repository.getRevenueReport(
          startDate: startDate,
          endDate: endDate,
          allLots: allLots,
        ),
        _repository.getOccupancyReport(),
        _repository.getWhatsappReport(
          startDate: startDate,
          endDate: endDate,
        ),
        _repository
            .getRevenueReport(
              startDate: previousStart,
              endDate: previousEnd,
              allLots: allLots,
            )
            .then<RevenueReport?>(
              (report) => report,
              onError: (Object _) => null,
            ),
      ]);
      final previous = results[3] as RevenueReport?;
      emit(
        ReportsLoaded(
          results[0] as RevenueReport,
          results[1] as OccupancyReport,
          whatsapp: results[2] as WhatsappReport,
          allLots: allLots,
          previousTotal: previous?.total,
          previousStart: previous == null ? null : previousStart,
          previousEnd: previous == null ? null : previousEnd,
        ),
      );
    } on Failure catch (failure) {
      emit(ReportsFailure.of(failure));
    }
  }
}
