import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/session_record.dart';
import '../domain/repositories/record_repository.dart';

enum RecordsStatus { initial, loading, loaded, failure }

class RecordsState extends Equatable {
  const RecordsState({
    this.status = RecordsStatus.initial,
    this.records = const [],
    this.total = 0,
    this.query = '',
    this.from,
    this.to,
    this.loadingMore = false,
    this.failure,
  });

  final RecordsStatus status;
  final List<SessionRecord> records;
  final int total;
  final String query;

  /// Inclusive business-date range (`null` = every date).
  final DateTime? from;
  final DateTime? to;
  final bool loadingMore;
  final Failure? failure;

  bool get hasMore => records.length < total;

  RecordsState copyWith({
    RecordsStatus? status,
    List<SessionRecord>? records,
    int? total,
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    bool? loadingMore,
    Failure? failure,
  }) => RecordsState(
    status: status ?? this.status,
    records: records ?? this.records,
    total: total ?? this.total,
    query: query ?? this.query,
    from: clearRange ? null : (from ?? this.from),
    to: clearRange ? null : (to ?? this.to),
    loadingMore: loadingMore ?? this.loadingMore,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    records,
    total,
    query,
    from,
    to,
    loadingMore,
    failure,
  ];
}

/// Activity log: latest sessions with a debounced plate filter and paging.
class RecordsCubit extends ResilientCubit<RecordsState> {
  RecordsCubit(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 300),
    this.pageSize = 50,
  }) : super(const RecordsState());

  final RecordRepository _repository;
  final Duration searchDebounce;
  final int pageSize;
  Timer? _timer;
  int _token = 0;

  Future<void> load({String? query}) async {
    final term = query ?? state.query;
    final token = ++_token;
    emit(
      state.copyWith(
        status: RecordsStatus.loading,
        query: term,
        failure: null,
      ),
    );
    try {
      final page = await _repository.list(
        plate: term,
        from: state.from,
        to: state.to,
        limit: pageSize,
      );
      if (isClosed || token != _token) {
        return;
      }
      emit(
        RecordsState(
          status: RecordsStatus.loaded,
          records: page.items,
          total: page.total,
          query: term,
          from: state.from,
          to: state.to,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || token != _token) {
        return;
      }
      emit(
        state.copyWith(status: RecordsStatus.failure, failure: failure),
      );
    }
  }

  void search(String query) {
    _timer?.cancel();
    _timer = Timer(searchDebounce, () => load(query: query));
  }

  /// `null` clears the range; otherwise both ends are inclusive.
  Future<void> setRange(DateTime? from, DateTime? to) async {
    if (from == null || to == null) {
      emit(state.copyWith(clearRange: true, failure: null));
    } else {
      emit(state.copyWith(from: from, to: to, failure: null));
    }
    await load();
  }

  /// Every row matching the current filter (for CSV/PDF), paging server-side.
  Future<List<SessionRecord>?> exportAll({int max = 2000}) async {
    final rows = <SessionRecord>[];
    var offset = 0;
    try {
      while (rows.length < max) {
        final page = await _repository.list(
          plate: state.query,
          from: state.from,
          to: state.to,
          offset: offset,
          limit: 200,
        );
        rows.addAll(page.items);
        if (rows.length >= page.total || page.items.isEmpty) {
          break;
        }
        offset += page.items.length;
      }
      return rows;
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(state.copyWith(failure: failure));
      }
      return null;
    }
  }

  Future<void> loadMore() async {
    if (state.status != RecordsStatus.loaded ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.list(
        plate: state.query,
        from: state.from,
        to: state.to,
        offset: state.records.length,
        limit: pageSize,
      );
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          records: [...state.records, ...page.items],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(state.copyWith(loadingMore: false, failure: failure));
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
