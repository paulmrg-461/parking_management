import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/loyalty_status.dart';
import '../domain/repositories/loyalty_repository.dart';

sealed class LoyaltyStatusState extends Equatable {
  const LoyaltyStatusState();

  @override
  List<Object?> get props => const [];
}

/// Hidden: no valid plate, program off or offline.
final class LoyaltyStatusIdle extends LoyaltyStatusState {
  const LoyaltyStatusIdle();
}

final class LoyaltyStatusLoading extends LoyaltyStatusState {
  const LoyaltyStatusLoading();
}

final class LoyaltyStatusReady extends LoyaltyStatusState {
  const LoyaltyStatusReady(this.status);

  final LoyaltyStatus status;

  @override
  List<Object?> get props => [status];
}

final class LoyaltyStatusFailure extends LoyaltyStatusState {
  const LoyaltyStatusFailure(this.message, {this.failure});

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

/// Check-in chip: never blocks the form, drops stale answers.
class LoyaltyStatusCubit extends ResilientCubit<LoyaltyStatusState> {
  LoyaltyStatusCubit(this._repository) : super(const LoyaltyStatusIdle());

  final LoyaltyRepository _repository;
  String? _plate;

  Future<void> load(String plate) async {
    final normalized = plate.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.length < 3) {
      _plate = null;
      emit(const LoyaltyStatusIdle());
      return;
    }
    _plate = normalized;
    emit(const LoyaltyStatusLoading());
    try {
      final status = await _repository.status(normalized);
      if (_plate != normalized) {
        return;
      }
      emit(
        status.enabled
            ? LoyaltyStatusReady(status)
            : const LoyaltyStatusIdle(),
      );
    } on NetworkFailure {
      if (_plate == normalized) {
        emit(const LoyaltyStatusIdle());
      }
    } on Failure catch (failure) {
      if (_plate == normalized) {
        emit(LoyaltyStatusFailure(failure.message, failure: failure));
      }
    }
  }

  /// Retries the last plate (the chip's retry button).
  Future<void> retry() async {
    final plate = _plate;
    if (plate != null) {
      await load(plate);
    }
  }

  void clear() {
    _plate = null;
    emit(const LoyaltyStatusIdle());
  }
}
