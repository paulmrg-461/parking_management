import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/resilient_cubit.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/lot_device.dart';
import '../domain/repositories/device_repository.dart';

sealed class DevicesState extends Equatable {
  const DevicesState();
  @override
  List<Object?> get props => const [];
}

final class DevicesLoading extends DevicesState {
  const DevicesLoading();
}

final class DevicesFailure extends DevicesState {
  const DevicesFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

final class DevicesLoaded extends DevicesState {
  const DevicesLoaded(this.list, {this.submission = const SubmissionIdle()});

  final DeviceList list;
  final Submission submission;

  DevicesLoaded copyWith({DeviceList? list, Submission? submission}) =>
      DevicesLoaded(list ?? this.list, submission: submission ?? this.submission);

  @override
  List<Object?> get props => [list.devices, list.offlineMinutes, submission];
}

class DevicesCubit extends ResilientCubit<DevicesState> {
  DevicesCubit(this._repository) : super(const DevicesLoading());

  final DeviceRepository _repository;

  Future<void> load() async {
    emit(const DevicesLoading());
    try {
      emit(DevicesLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(DevicesFailure(failure));
    }
  }

  Future<LotDevice?> register(DeviceKind kind, String name) async {
    final current = state;
    if (current is! DevicesLoaded) return null;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final device = await _repository.register(kind: kind, name: name);
      await _refresh(current, SubmissionSucceeded<LotDevice>(device));
      return device;
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
      return null;
    }
  }

  Future<LotDevice?> rotate(int id) async {
    final current = state;
    if (current is! DevicesLoaded) return null;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      final device = await _repository.rotate(id);
      await _refresh(current, SubmissionSucceeded<LotDevice>(device));
      return device;
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
      return null;
    }
  }

  Future<void> toggle(LotDevice device) async {
    final current = state;
    if (current is! DevicesLoaded) return;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.update(device.id, enabled: !device.enabled);
      await _refresh(current, const SubmissionSucceeded<Object?>(null));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> rename(LotDevice device, String name) async {
    final current = state;
    if (current is! DevicesLoaded) return;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.update(device.id, name: name);
      await _refresh(current, const SubmissionSucceeded<Object?>(null));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> delete(int id) async {
    final current = state;
    if (current is! DevicesLoaded) return;
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await _repository.delete(id);
      await _refresh(current, const SubmissionSucceeded<Object?>(null));
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<void> setOfflineMinutes(int minutes) async {
    final current = state;
    if (current is! DevicesLoaded) return;
    try {
      final saved = await _repository.setOfflineMinutes(minutes);
      emit(
        current.copyWith(
          list: DeviceList(offlineMinutes: saved, devices: current.list.devices),
          submission: const SubmissionSucceeded<Object?>(null),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  Future<List<DeviceEvent>> events(int? deviceId) =>
      _repository.events(deviceId);

  Future<void> _refresh(DevicesLoaded current, Submission submission) async {
    try {
      final list = await _repository.list();
      emit(DevicesLoaded(list, submission: submission));
    } on Failure {
      emit(current.copyWith(submission: submission));
    }
  }
}
