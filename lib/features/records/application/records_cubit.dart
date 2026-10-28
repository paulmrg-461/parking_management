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
    this.loadingMore = false,
    this.failure,
  });

  final RecordsStatus status;
  final List<SessionRecord> records;
  final int total;
  final String query;
  final bool loadingMore;
  final Failure? failure;

  bool get hasMore => records.length < total;

  RecordsState copyWith({
    RecordsStatus? status,
    List<SessionRecord>? records,
    int? total,
    String? query,
    bool? loadingMore,
    Failure? failure,
  }) => RecordsState(
    status: status ?? this.status,
    records: records ?? this.records,
    total: total ?? this.total,
    query: query ?? this.query,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    records,
    total,
    query,
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
      final page = await _repository.list(plate: term, limit: pageSize);
      if (isClosed || token != _token) {
        return;
      }
      emit(
        RecordsState(
          status: RecordsStatus.loaded,
          records: page.items,
          total: page.total,
          query: term,
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
