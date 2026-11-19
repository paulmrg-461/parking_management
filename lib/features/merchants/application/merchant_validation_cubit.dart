import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/merchant_portal.dart';
import '../domain/entities/merchant_validation_result.dart';
import '../domain/repositories/public_merchant_repository.dart';

sealed class MerchantValidationState extends Equatable {
  const MerchantValidationState();

  @override
  List<Object?> get props => const [];
}

final class MerchantValidationInitial extends MerchantValidationState {
  const MerchantValidationInitial();
}

final class MerchantValidationLoading extends MerchantValidationState {
  const MerchantValidationLoading();
}

final class MerchantValidationInvalidLink extends MerchantValidationState {
  const MerchantValidationInvalidLink();
}

final class MerchantValidationReady extends MerchantValidationState {
  const MerchantValidationReady(
    this.portal, {
    this.submitting = false,
    this.attemptsLeft,
    this.lockedUntil,
    this.actionFailure,
  });

  final MerchantPortal portal;
  final bool submitting;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
  final Failure? actionFailure;

  MerchantValidationReady copyWith({
    bool? submitting,
    int? attemptsLeft,
    DateTime? lockedUntil,
    Failure? actionFailure,
    bool clearActionFailure = false,
  }) => MerchantValidationReady(
    portal,
    submitting: submitting ?? this.submitting,
    attemptsLeft: attemptsLeft ?? this.attemptsLeft,
    lockedUntil: lockedUntil ?? this.lockedUntil,
    actionFailure: clearActionFailure
        ? null
        : (actionFailure ?? this.actionFailure),
  );

  @override
  List<Object?> get props => [
    portal,
    submitting,
    attemptsLeft,
    lockedUntil,
    actionFailure?.message,
  ];
}

final class MerchantValidationDone extends MerchantValidationState {
  const MerchantValidationDone(this.portal);

  final MerchantPortal portal;

  @override
  List<Object?> get props => [portal];
}

final class MerchantValidationFailure extends MerchantValidationState {
  const MerchantValidationFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

/// Public page: load the portal from the token and validate a plate + PIN.
/// The PIN only lives in the page, never in the cubit.
class MerchantValidationCubit extends ResilientCubit<MerchantValidationState> {
  MerchantValidationCubit(this._repository)
    : super(const MerchantValidationInitial());

  final PublicMerchantRepository _repository;
  String? _token;

  Future<void> load(String token) async {
    _token = token;
    emit(const MerchantValidationLoading());
    try {
      final portal = await _repository.portal(token);
      emit(
        portal == null
            ? const MerchantValidationInvalidLink()
            : MerchantValidationReady(portal),
      );
    } on Failure catch (failure) {
      emit(MerchantValidationFailure(failure));
    }
  }

  Future<void> submit({required String pin, required String plate}) async {
    final current = state;
    final token = _token;
    if (current is! MerchantValidationReady || token == null) {
      return;
    }
    emit(current.copyWith(submitting: true, clearActionFailure: true));
    try {
      final result = await _repository.validate(
        token: token,
        pin: pin,
        plate: plate,
      );
      switch (result) {
        case ValidationRegistered(:final summary):
          emit(MerchantValidationDone(summary));
        case ValidationInvalidPin(:final attemptsLeft):
          emit(current.copyWith(submitting: false, attemptsLeft: attemptsLeft));
        case ValidationLocked(:final until):
          emit(current.copyWith(submitting: false, lockedUntil: until));
      }
    } on Failure catch (failure) {
      emit(
        current.copyWith(submitting: false, actionFailure: failure),
      );
    }
  }

  void another() {
    final current = state;
    if (current is MerchantValidationDone) {
      emit(MerchantValidationReady(current.portal));
    }
  }
}
