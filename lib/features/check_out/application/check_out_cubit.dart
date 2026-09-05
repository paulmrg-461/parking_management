import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import '../domain/repositories/check_out_repository.dart';

sealed class CheckOutState extends Equatable {
  const CheckOutState();

  @override
  List<Object?> get props => const [];
}

class CheckOutInitial extends CheckOutState {
  const CheckOutInitial();
}

class CheckOutLoading extends CheckOutState {
  const CheckOutLoading();
}

class CheckOutLoaded extends CheckOutState {
  const CheckOutLoaded(this.sessions);

  final List<OpenSession> sessions;

  @override
  List<Object?> get props => [sessions];
}

class CheckOutProcessing extends CheckOutState {
  const CheckOutProcessing();
}

class CheckOutSuccess extends CheckOutState {
  const CheckOutSuccess(this.receipt);

  final CheckOutReceipt receipt;

  @override
  List<Object?> get props => [receipt];
}

class CheckOutFailure extends CheckOutState {
  const CheckOutFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Orchestrates the check-out flow: loads currently open sessions and closes
/// one of them, refreshing the open-sessions list afterwards so the just
/// closed session disappears from it.
class CheckOutCubit extends Cubit<CheckOutState> {
  CheckOutCubit(this._repository) : super(const CheckOutInitial());

  final CheckOutRepository _repository;

  Future<void> loadOpenSessions() async {
    emit(const CheckOutLoading());
    try {
      emit(CheckOutLoaded(await _repository.listOpenSessions()));
    } on Failure catch (failure) {
      emit(CheckOutFailure(failure.message));
    }
  }

  /// Closes the session identified by [sessionId] and refreshes the
  /// open-sessions list internally before emitting [CheckOutSuccess], so
  /// that the list is already up to date by the time the page moves past
  /// the receipt.
  Future<void> checkOut(int sessionId) async {
    emit(const CheckOutProcessing());
    try {
      final receipt = await _repository.checkOut(sessionId);
      await loadOpenSessions();
      emit(CheckOutSuccess(receipt));
    } on Failure catch (failure) {
      emit(CheckOutFailure(failure.message));
    }
  }
}
