import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/client_error_report.dart';
import '../domain/entities/diagnostics_snapshot.dart';
import '../domain/repositories/diagnostics_repository.dart';

sealed class DiagnosticsState extends Equatable {
  const DiagnosticsState();

  @override
  List<Object?> get props => const [];
}

final class DiagnosticsInitial extends DiagnosticsState {
  const DiagnosticsInitial();
}

final class DiagnosticsLoading extends DiagnosticsState {
  const DiagnosticsLoading();
}

final class DiagnosticsLoaded extends DiagnosticsState {
  const DiagnosticsLoaded(this.snapshot, this.errors);

  final DiagnosticsSnapshot snapshot;
  final List<ClientErrorReport> errors;

  @override
  List<Object?> get props => [snapshot, errors];
}

final class DiagnosticsFailure extends DiagnosticsState {
  const DiagnosticsFailure(this.message, {this.failure});

  DiagnosticsFailure.of(Failure failure)
    : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class DiagnosticsCubit extends ResilientCubit<DiagnosticsState> {
  DiagnosticsCubit(this._repository) : super(const DiagnosticsInitial());

  final DiagnosticsRepository _repository;

  Future<void> load() async {
    emit(const DiagnosticsLoading());
    try {
      final results = await Future.wait([
        _repository.snapshot(),
        _repository.clientErrors(),
      ]);
      emit(
        DiagnosticsLoaded(
          results[0] as DiagnosticsSnapshot,
          results[1] as List<ClientErrorReport>,
        ),
      );
    } on Failure catch (failure) {
      emit(DiagnosticsFailure.of(failure));
    }
  }
}
