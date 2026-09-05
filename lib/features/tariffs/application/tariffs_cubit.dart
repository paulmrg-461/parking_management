import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import '../domain/repositories/tariff_repository.dart';

sealed class TariffsState extends Equatable {
  const TariffsState();

  @override
  List<Object?> get props => const [];
}

class TariffsInitial extends TariffsState {
  const TariffsInitial();
}

class TariffsLoading extends TariffsState {
  const TariffsLoading();
}

class TariffsLoaded extends TariffsState {
  const TariffsLoaded(this.tariffs);

  final List<Tariff> tariffs;

  @override
  List<Object?> get props => [tariffs];
}

class TariffsFailure extends TariffsState {
  const TariffsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class TariffsCubit extends Cubit<TariffsState> {
  TariffsCubit(this._repository) : super(const TariffsInitial());

  final TariffRepository _repository;

  Future<void> load() async {
    emit(const TariffsLoading());
    try {
      emit(TariffsLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(TariffsFailure(failure.message));
    }
  }

  Future<void> create(CreateTariffCommand command) async {
    await _run(() => _repository.create(command));
  }

  Future<void> update(UpdateTariffCommand command) async {
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
      emit(TariffsFailure(failure.message));
    }
  }
}
