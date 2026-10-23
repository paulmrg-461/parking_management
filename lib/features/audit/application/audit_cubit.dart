import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/audit_entry.dart';
import '../domain/repositories/audit_repository.dart';

sealed class AuditState extends Equatable {
  const AuditState();

  @override
  List<Object?> get props => const [];
}

final class AuditInitial extends AuditState {
  const AuditInitial();
}

final class AuditLoading extends AuditState {
  const AuditLoading();
}

final class AuditLoaded extends AuditState {
  const AuditLoaded(
    this.entries, {
    this.from,
    this.to,
    this.table,
  });

  final List<AuditEntry> entries;
  final DateTime? from;
  final DateTime? to;
  final String? table;

  @override
  List<Object?> get props => [entries, from, to, table];
}

final class AuditFailure extends AuditState {
  const AuditFailure(this.message, {this.failure});

  AuditFailure.of(Failure failure)
    : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class AuditCubit extends ResilientCubit<AuditState> {
  AuditCubit(this._repository) : super(const AuditInitial());

  final AuditRepository _repository;

  Future<void> load({
    DateTime? from,
    DateTime? to,
    String? table,
    bool clearFilters = false,
  }) async {
    final current = state;
    final previous = current is AuditLoaded ? current : null;
    final nextFrom = clearFilters ? null : (from ?? previous?.from);
    final nextTo = clearFilters ? null : (to ?? previous?.to);
    final nextTable = clearFilters ? null : (table ?? previous?.table);

    emit(const AuditLoading());
    try {
      final entries = await _repository.list(
        from: nextFrom,
        to: nextTo,
        table: nextTable,
      );
      emit(AuditLoaded(entries, from: nextFrom, to: nextTo, table: nextTable));
    } on Failure catch (failure) {
      emit(AuditFailure.of(failure));
    }
  }
}
