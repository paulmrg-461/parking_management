import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/public_evidence.dart';
import '../domain/repositories/evidence_repository.dart';

enum EvidenceStatus { initial, loading, loaded, failure }

class EvidenceState extends Equatable {
  const EvidenceState({
    this.status = EvidenceStatus.initial,
    this.evidence,
    this.failure,
  });

  final EvidenceStatus status;
  final PublicEvidence? evidence;
  final Failure? failure;

  EvidenceState copyWith({
    EvidenceStatus? status,
    PublicEvidence? evidence,
    Failure? failure,
  }) => EvidenceState(
    status: status ?? this.status,
    evidence: evidence ?? this.evidence,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, evidence, failure];
}

/// Public evidence loader (no session: the plate is the key).
class EvidenceCubit extends ResilientCubit<EvidenceState> {
  EvidenceCubit(this._repository) : super(const EvidenceState());

  final EvidenceRepository _repository;

  Future<void> load({required int? sessionId, required String? plate}) async {
    if (sessionId == null || sessionId <= 0 || (plate ?? '').trim().isEmpty) {
      emit(
        const EvidenceState(
          status: EvidenceStatus.failure,
          failure: ValidationFailure('Invalid evidence link', 'EvidenceNotFoundError'),
        ),
      );
      return;
    }
    emit(state.copyWith(status: EvidenceStatus.loading, failure: null));
    try {
      final evidence = await _repository.fetch(
        sessionId: sessionId,
        plate: plate!,
      );
      if (!isClosed) {
        emit(EvidenceState(status: EvidenceStatus.loaded, evidence: evidence));
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(EvidenceState(status: EvidenceStatus.failure, failure: failure));
      }
    }
  }
}
