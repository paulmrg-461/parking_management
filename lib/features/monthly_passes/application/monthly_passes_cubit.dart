import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/repositories/monthly_pass_repository.dart';

sealed class MonthlyPassesState extends Equatable {
  const MonthlyPassesState();

  @override
  List<Object?> get props => const [];
}

class MonthlyPassesInitial extends MonthlyPassesState {
  const MonthlyPassesInitial();
}

class MonthlyPassesLoading extends MonthlyPassesState {
  const MonthlyPassesLoading();
}

class MonthlyPassesLoaded extends MonthlyPassesState {
  const MonthlyPassesLoaded(this.monthlyPasses);

  final List<MonthlyPass> monthlyPasses;

  @override
  List<Object?> get props => [monthlyPasses];
}

class MonthlyPassesFailure extends MonthlyPassesState {
  const MonthlyPassesFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class MonthlyPassesCubit extends Cubit<MonthlyPassesState> {
  MonthlyPassesCubit(this._repository) : super(const MonthlyPassesInitial());

  final MonthlyPassRepository _repository;

  Future<void> load({int? vehicleId}) async {
    emit(const MonthlyPassesLoading());
    try {
      emit(MonthlyPassesLoaded(await _repository.list(vehicleId: vehicleId)));
    } on Failure catch (failure) {
      emit(MonthlyPassesFailure(failure.message));
    }
  }

  Future<void> create(CreateMonthlyPassCommand command) async {
    await _run(() => _repository.create(command));
  }

  Future<void> update(UpdateMonthlyPassCommand command) async {
    await _run(() => _repository.update(command));
  }

  Future<void> delete(int id) async {
    await _run(() => _repository.delete(id));
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await load();
    } on Failure catch (failure) {
      emit(MonthlyPassesFailure(failure.message));
    }
  }
}
