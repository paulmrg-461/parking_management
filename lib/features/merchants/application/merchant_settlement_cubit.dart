import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../domain/entities/merchant_settlement.dart';
import '../domain/repositories/merchant_repository.dart';

sealed class MerchantSettlementState extends Equatable {
  const MerchantSettlementState();

  @override
  List<Object?> get props => const [];
}

final class MerchantSettlementInitial extends MerchantSettlementState {
  const MerchantSettlementInitial();
}

final class MerchantSettlementLoading extends MerchantSettlementState {
  const MerchantSettlementLoading();
}

final class MerchantSettlementLoaded extends MerchantSettlementState {
  const MerchantSettlementLoaded(this.settlement);

  final MerchantSettlement settlement;

  @override
  List<Object?> get props => [settlement];
}

final class MerchantSettlementFailure extends MerchantSettlementState {
  const MerchantSettlementFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure.message, failure.code];
}

class MerchantSettlementCubit extends ResilientCubit<MerchantSettlementState> {
  MerchantSettlementCubit(this._repository)
    : super(const MerchantSettlementInitial());

  final MerchantRepository _repository;
  DateTime? _start;
  DateTime? _end;

  Future<void> load({required DateTime start, required DateTime end}) async {
    _start = start;
    _end = end;
    emit(const MerchantSettlementLoading());
    try {
      emit(MerchantSettlementLoaded(
        await _repository.settlement(start: start, end: end),
      ));
    } on Failure catch (failure) {
      emit(MerchantSettlementFailure(failure));
    }
  }

  Future<void> retry() async {
    final start = _start;
    final end = _end;
    if (start != null && end != null) {
      await load(start: start, end: end);
    }
  }
}
