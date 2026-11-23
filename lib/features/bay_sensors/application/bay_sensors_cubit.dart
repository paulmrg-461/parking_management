import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/commands/bay_commands.dart';
import '../domain/entities/bay_sensor.dart';
import '../domain/repositories/bay_repository.dart';

sealed class BaySensorsState {
  const BaySensorsState();
}

final class BaySensorsLoading extends BaySensorsState {
  const BaySensorsLoading();
}

final class BaySensorsFailure extends BaySensorsState {
  const BaySensorsFailure(this.failure);
  final Failure failure;
}

final class BaySensorsEmpty extends BaySensorsState {
  const BaySensorsEmpty({this.submission = const SubmissionIdle()});
  final Submission submission;

  BaySensorsEmpty withSubmission(Submission value) =>
      BaySensorsEmpty(submission: value);
}

final class BaySensorsLoaded extends BaySensorsState {
  const BaySensorsLoaded(
    this.mapped,
    this.unmapped, {
    this.submission = const SubmissionIdle(),
  });

  final List<BaySensor> mapped;
  final List<BaySensor> unmapped;
  final Submission submission;

  BaySensorsLoaded withSubmission(Submission value) =>
      BaySensorsLoaded(mapped, unmapped, submission: value);

  BaySensor? forSpot(int spotId) {
    for (final sensor in mapped) {
      if (sensor.spotId == spotId) return sensor;
    }
    return null;
  }
}

/// Editor side of the sensors: what the bay sheet lists and maps.
class BaySensorsCubit extends ResilientCubit<BaySensorsState> {
  BaySensorsCubit(this._repository) : super(const BaySensorsLoading());

  final BayRepository _repository;

  Future<void> load() async {
    emit(const BaySensorsLoading());
    await _fetch();
  }

  Future<void> map(MapBaySensor command) async {
    final current = state;
    if (current is! BaySensorsLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.withSubmission(const SubmissionInProgress()));
    try {
      await _repository.mapSensor(command);
      await _fetch(submission: const SubmissionSucceeded<void>(null));
    } on Failure catch (failure) {
      emit(current.withSubmission(SubmissionFailed.of(failure)));
    }
  }

  Future<void> unmap(int sensorId) async {
    final current = state;
    if (current is! BaySensorsLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.withSubmission(const SubmissionInProgress()));
    try {
      await _repository.unmapSensor(sensorId);
      await _fetch(submission: const SubmissionSucceeded<void>(null));
    } on Failure catch (failure) {
      emit(current.withSubmission(SubmissionFailed.of(failure)));
    }
  }

  Future<void> setThreshold(SensorThresholdUpdate update) async {
    final current = state;
    if (current is! BaySensorsLoaded) return;
    if (current.submission.isInProgress) return;
    emit(current.withSubmission(const SubmissionInProgress()));
    try {
      await _repository.setThreshold(update);
      await _fetch(submission: const SubmissionSucceeded<void>(null));
    } on Failure catch (failure) {
      emit(current.withSubmission(SubmissionFailed.of(failure)));
    }
  }

  Future<void> _fetch({
    Submission submission = const SubmissionIdle(),
  }) async {
    try {
      final result = await _repository.sensors();
      if (result.mapped.isEmpty && result.unmapped.isEmpty) {
        emit(BaySensorsEmpty(submission: submission));
      } else {
        emit(BaySensorsLoaded(
          result.mapped,
          result.unmapped,
          submission: submission,
        ));
      }
    } on Failure catch (failure) {
      emit(BaySensorsFailure(failure));
    }
  }
}
