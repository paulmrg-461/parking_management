import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/commands/lpr_settings_update.dart';
import '../domain/entities/lpr_settings.dart';
import '../domain/repositories/lpr_repository.dart';

sealed class LprSettingsState {
  const LprSettingsState();
}

final class LprSettingsLoading extends LprSettingsState {
  const LprSettingsLoading();
}

final class LprSettingsFailure extends LprSettingsState {
  const LprSettingsFailure(this.failure);
  final Failure failure;
}

final class LprSettingsNoCameras extends LprSettingsState {
  const LprSettingsNoCameras(this.settings, {this.submission = const SubmissionIdle()});
  final LprSettings settings;
  final Submission submission;

  LprSettingsNoCameras withSubmission(Submission value) =>
      LprSettingsNoCameras(settings, submission: value);
}

final class LprSettingsLoaded extends LprSettingsState {
  const LprSettingsLoaded(this.settings, {this.submission = const SubmissionIdle()});
  final LprSettings settings;
  final Submission submission;

  LprSettingsLoaded withSubmission(Submission value) =>
      LprSettingsLoaded(settings, submission: value);
}

/// Admin settings for the plate camera. Every save answers with the stored
/// settings, so the screen never guesses what the server accepted.
class LprSettingsCubit extends ResilientCubit<LprSettingsState> {
  LprSettingsCubit(this._repository) : super(const LprSettingsLoading());

  final LprRepository _repository;

  Future<void> load() async {
    emit(const LprSettingsLoading());
    await _fetch();
  }

  Future<void> save(LprSettingsUpdate update) async {
    final current = state;
    if (current is! LprSettingsLoaded && current is! LprSettingsNoCameras) {
      return;
    }
    if (_isBusy(current)) return;
    emit(_withSubmission(current, const SubmissionInProgress()));
    try {
      final settings = await _repository.saveSettings(update);
      emit(_withSettings(settings, const SubmissionSucceeded<void>(null)));
    } on Failure catch (failure) {
      emit(_withSubmission(current, SubmissionFailed.of(failure)));
    }
  }

  Future<void> setDirection(int deviceId, String direction) async {
    final current = state;
    if (current is! LprSettingsLoaded && current is! LprSettingsNoCameras) {
      return;
    }
    if (_isBusy(current)) return;
    emit(_withSubmission(current, const SubmissionInProgress()));
    try {
      await _repository.setCameraDirection(
        deviceId: deviceId,
        direction: direction,
      );
      await _fetch();
    } on Failure catch (failure) {
      emit(_withSubmission(current, SubmissionFailed.of(failure)));
    }
  }

  Future<void> _fetch() async {
    try {
      emit(_withSettings(await _repository.settings()));
    } on Failure catch (failure) {
      emit(LprSettingsFailure(failure));
    }
  }

  LprSettingsState _withSettings(
    LprSettings settings, [
    Submission submission = const SubmissionIdle(),
  ]) => settings.hasCameras
      ? LprSettingsLoaded(settings, submission: submission)
      : LprSettingsNoCameras(settings, submission: submission);

  bool _isBusy(LprSettingsState state) => switch (state) {
    LprSettingsLoaded(:final submission) => submission.isInProgress,
    LprSettingsNoCameras(:final submission) => submission.isInProgress,
    _ => true,
  };

  LprSettingsState _withSubmission(
    LprSettingsState current,
    Submission value,
  ) {
    if (current is LprSettingsLoaded) return current.withSubmission(value);
    if (current is LprSettingsNoCameras) return current.withSubmission(value);
    return current;
  }
}
