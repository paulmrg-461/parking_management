import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/anomaly_settings.dart';
import '../domain/entities/cash_anomaly.dart';
import '../domain/repositories/anomaly_repository.dart';

sealed class AnomaliesState extends Equatable {
  const AnomaliesState();

  @override
  List<Object?> get props => const [];
}

final class AnomaliesInitial extends AnomaliesState {
  const AnomaliesInitial();
}

final class AnomaliesLoading extends AnomaliesState {
  const AnomaliesLoading();
}

final class AnomaliesLoaded extends AnomaliesState {
  const AnomaliesLoaded(
    this.list, {
    this.status = AnomalyStatus.open,
    this.rule,
    this.severity,
    this.resolvingId,
    this.notice,
  });

  final AnomalyList list;
  final AnomalyStatus status;
  final AnomalyRule? rule;
  final AnomalySeverity? severity;

  /// The anomaly being acknowledged/dismissed.
  final int? resolvingId;

  /// The last review failed; the list is untouched.
  final Failure? notice;

  bool get isFiltered =>
      status != AnomalyStatus.open || rule != null || severity != null;

  AnomaliesLoaded copyWith({
    AnomalyList? list,
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
    int? resolvingId,
    bool clearRule = false,
    bool clearSeverity = false,
    bool clearResolving = false,
    Failure? notice,
    bool clearNotice = false,
  }) => AnomaliesLoaded(
    list ?? this.list,
    status: status ?? this.status,
    rule: clearRule ? null : (rule ?? this.rule),
    severity: clearSeverity ? null : (severity ?? this.severity),
    resolvingId: clearResolving ? null : (resolvingId ?? this.resolvingId),
    notice: clearNotice ? null : (notice ?? this.notice),
  );

  @override
  List<Object?> get props => [list, status, rule, severity, resolvingId, notice];
}

final class AnomaliesFailure extends AnomaliesState {
  const AnomaliesFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

class AnomaliesCubit extends ResilientCubit<AnomaliesState> {
  AnomaliesCubit(this._repository) : super(const AnomaliesInitial());

  final AnomalyRepository _repository;

  AnomalyStatus _status = AnomalyStatus.open;
  AnomalyRule? _rule;
  AnomalySeverity? _severity;

  Future<void> load({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
    bool clearFilters = false,
  }) async {
    if (clearFilters) {
      _status = AnomalyStatus.open;
      _rule = null;
      _severity = null;
    }
    _status = status ?? _status;
    _rule = rule ?? _rule;
    _severity = severity ?? _severity;
    emit(const AnomaliesLoading());
    try {
      final list = await _repository.list(
        status: _status,
        rule: _rule,
        severity: _severity,
      );
      if (!isClosed) {
        emit(
          AnomaliesLoaded(
            list,
            status: _status,
            rule: _rule,
            severity: _severity,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(AnomaliesFailure(failure));
      }
    }
  }

  /// Acknowledges or dismisses one anomaly and reloads with the same filters.
  Future<void> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  }) async {
    final current = state;
    if (current is! AnomaliesLoaded) {
      return;
    }
    emit(current.copyWith(resolvingId: id, clearNotice: true));
    try {
      await _repository.resolve(id: id, status: status, note: note);
      if (!isClosed) {
        await load();
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(current.copyWith(clearResolving: true, notice: failure));
      }
    }
  }

  Future<AnomalySettings> loadSettings() => _repository.loadSettings();

  Future<AnomalySettings> saveSettings(AnomalySettings settings) =>
      _repository.saveSettings(settings);
}
