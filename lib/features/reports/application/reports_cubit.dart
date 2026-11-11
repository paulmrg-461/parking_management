import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/hourly_traffic.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/period_comparison.dart';
import '../domain/entities/reservation_report.dart';
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
    this.hourly = HourlyTraffic.empty,
    this.reservations = ReservationReport.empty,
    this.comparison = PeriodComparison.empty,
    this.comparisonMonths = 6,
    this.comparisonFailed = false,
    this.comparisonLoading = false,
    this.allLots = false,
    this.previousTotal,
    this.previousStart,
    this.previousEnd,
  });

  final RevenueReport revenue;
  final OccupancyReport occupancy;
  final WhatsappReport whatsapp;

  /// Entries/exits per hour (empty when the RPC failed).
  final HourlyTraffic hourly;

  /// Holds created in the window, by origin and outcome.
  final ReservationReport reservations;

  /// Trailing months with the month before and the same month last year.
  final PeriodComparison comparison;
  final int comparisonMonths;

  /// The last comparison request failed (the section offers a retry).
  final bool comparisonFailed;

  /// A months switch or a retry is in flight (the section shows a skeleton).
  final bool comparisonLoading;

  ReportsLoaded copyWith({
    PeriodComparison? comparison,
    int? comparisonMonths,
    bool? comparisonFailed,
    bool? comparisonLoading,
  }) => ReportsLoaded(
    revenue,
    occupancy,
    whatsapp: whatsapp,
    hourly: hourly,
    reservations: reservations,
    comparison: comparison ?? this.comparison,
    comparisonMonths: comparisonMonths ?? this.comparisonMonths,
    comparisonFailed: comparisonFailed ?? this.comparisonFailed,
    comparisonLoading: comparisonLoading ?? this.comparisonLoading,
    allLots: allLots,
    previousTotal: previousTotal,
    previousStart: previousStart,
    previousEnd: previousEnd,
  );

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
    hourly,
    reservations,
    comparison,
    comparisonMonths,
    comparisonFailed,
    comparisonLoading,
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
    int comparisonMonths = 6,
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
        _repository.getWhatsappReport(startDate: startDate, endDate: endDate),
        _repository
            .getHourlyTraffic(startDate: startDate, endDate: endDate)
            .then<HourlyTraffic>(
              (report) => report,
              onError: (Object _) => HourlyTraffic.empty,
            ),
        _repository
            .getPeriodComparison(months: comparisonMonths)
            .then<PeriodComparison?>(
              (report) => report,
              onError: (Object _) => null,
            ),
        _repository
            .getReservationReport(startDate: startDate, endDate: endDate)
            .then<ReservationReport>(
              (report) => report,
              onError: (Object _) => ReservationReport.empty,
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
      final previous = results[6] as RevenueReport?;
      emit(
        ReportsLoaded(
          results[0] as RevenueReport,
          results[1] as OccupancyReport,
          whatsapp: results[2] as WhatsappReport,
          hourly: results[3] as HourlyTraffic,
          reservations: results[5] as ReservationReport,
          comparison:
              (results[4] as PeriodComparison?) ?? PeriodComparison.empty,
          comparisonMonths: comparisonMonths,
          comparisonFailed: results[4] == null,
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

  /// Switches the comparison between 6 and 12 months (or retries it) without
  /// flashing the page: it stays on [ReportsLoaded] and never emits the
  /// loading or failure state of the whole report.
  Future<void> loadComparison({required int months}) async {
    final current = state;
    if (current is! ReportsLoaded) {
      return;
    }
    emit(current.copyWith(comparisonLoading: true, comparisonMonths: months));
    try {
      final report = await _repository.getPeriodComparison(months: months);
      final latest = state;
      if (isClosed || latest is! ReportsLoaded) {
        return;
      }
      emit(
        latest.copyWith(
          comparison: report,
          comparisonMonths: months,
          comparisonFailed: false,
          comparisonLoading: false,
        ),
      );
    } on Failure {
      final latest = state;
      if (isClosed || latest is! ReportsLoaded) {
        return;
      }
      emit(
        latest.copyWith(
          comparison: PeriodComparison.empty,
          comparisonMonths: months,
          comparisonFailed: true,
          comparisonLoading: false,
        ),
      );
    }
  }
}
