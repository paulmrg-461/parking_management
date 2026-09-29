import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/parking_settings.dart';
import '../domain/repositories/parking_settings_repository.dart';

sealed class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => const [];
}

final class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(
    this.settings, {
    this.submission = const SubmissionIdle(),
  });

  final ParkingSettings settings;
  final Submission submission;

  @override
  List<Object?> get props => [settings, submission];
}

/// The record itself could not be loaded (action errors never land here).
final class SettingsFailure extends SettingsState {
  const SettingsFailure(this.message, {this.failure});

  SettingsFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsInitial());

  final ParkingSettingsRepository _repository;

  Future<void> load() async {
    emit(const SettingsLoading());
    try {
      emit(SettingsLoaded(await _repository.load()));
    } on Failure catch (failure) {
      emit(SettingsFailure.of(failure));
    }
  }

  Future<void> save(ParkingSettings settings) => _submit(
    () => _repository.save(settings),
  );

  Future<void> uploadLogo(Uint8List bytes) => _submit(
    () => _repository.uploadLogo(bytes),
  );

  /// Keeps the form data on screen while a submission runs; a failing
  /// action reports through [SubmissionFailed] instead of wiping state.
  Future<void> _submit(Future<ParkingSettings> Function() action) async {
    final current = state;
    final settings = current is SettingsLoaded
        ? current.settings
        : ParkingSettings.defaults();
    emit(SettingsLoaded(settings, submission: const SubmissionInProgress()));
    try {
      final updated = await action();
      emit(SettingsLoaded(updated, submission: SubmissionSucceeded(updated)));
    } on Failure catch (failure) {
      emit(
        SettingsLoaded(settings, submission: SubmissionFailed.of(failure)),
      );
    }
  }
}
