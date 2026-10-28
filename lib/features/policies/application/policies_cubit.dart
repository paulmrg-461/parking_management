import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/lot_profile.dart';
import '../domain/repositories/policy_repository.dart';

enum PoliciesStatus { initial, loading, loaded, failure }

class PoliciesState extends Equatable {
  const PoliciesState({
    this.status = PoliciesStatus.initial,
    this.profile,
    this.failure,
  });

  final PoliciesStatus status;
  final LotProfile? profile;
  final Failure? failure;

  @override
  List<Object?> get props => [status, profile, failure];
}

class PoliciesCubit extends ResilientCubit<PoliciesState> {
  PoliciesCubit(this._repository) : super(const PoliciesState());

  final PolicyRepository _repository;

  Future<void> load(int? lotId) async {
    if (lotId == null || lotId <= 0) {
      emit(
        const PoliciesState(
          status: PoliciesStatus.failure,
          failure: ValidationFailure('Policy not available', 'PolicyNotFoundError'),
        ),
      );
      return;
    }
    emit(const PoliciesState(status: PoliciesStatus.loading));
    try {
      final profile = await _repository.fetch(lotId);
      if (!isClosed) {
        emit(PoliciesState(status: PoliciesStatus.loaded, profile: profile));
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(PoliciesState(status: PoliciesStatus.failure, failure: failure));
      }
    }
  }
}
