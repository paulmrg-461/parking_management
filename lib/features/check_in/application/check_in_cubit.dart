import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import '../domain/repositories/check_in_repository.dart';
import 'create_check_in.dart';

enum SessionsStatus { loading, loaded, failure }

/// Open-sessions list and the check-in [submission] are orthogonal: the form
/// works (and queues offline) even when the list failed to load, and a
/// failed submit never hides the list.
class CheckInState extends Equatable {
  const CheckInState({
    this.status = SessionsStatus.loading,
    this.sessions = const [],
    this.loadError,
    this.loadFailure,
    this.submission = const SubmissionIdle(),
  });

  final SessionsStatus status;
  final List<ParkingSession> sessions;
  final String? loadError;
  final Failure? loadFailure;
  final Submission submission;

  CheckInState copyWith({
    SessionsStatus? status,
    List<ParkingSession>? sessions,
    String? loadError,
    Failure? loadFailure,
    Submission? submission,
  }) => CheckInState(
    status: status ?? this.status,
    sessions: sessions ?? this.sessions,
    loadError: loadError,
    loadFailure: loadFailure,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [
    status,
    sessions,
    loadError,
    loadFailure?.code,
    submission,
  ];
}

class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit(this._createCheckIn, this._repository)
    : super(const CheckInState());

  final CreateCheckIn _createCheckIn;
  final CheckInRepository _repository;

  Future<void> loadOpenSessions() async {
    emit(state.copyWith(status: SessionsStatus.loading));
    try {
      final sessions = await _repository.listOpenSessions();
      emit(state.copyWith(status: SessionsStatus.loaded, sessions: sessions));
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: SessionsStatus.failure,
          loadError: failure.message,
          loadFailure: failure,
        ),
      );
    }
  }

  /// Submits a check-in; validation happens in [CreateCheckIn]. [newVehicle]
  /// is only passed when the plate is not yet registered.
  Future<void> submitCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    emit(state.copyWith(submission: const SubmissionInProgress()));
    try {
      final session = await _createCheckIn(
        plate: plate,
        photos: photos,
        newVehicle: newVehicle,
      );
      emit(
        state.copyWith(
          status: SessionsStatus.loaded,
          sessions: await _sessionsAfter(session),
          submission: SubmissionSucceeded<ParkingSession>(session),
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  /// Fresh list from the server; offline, the new (pending) session is
  /// prepended to what is already on screen.
  Future<List<ParkingSession>> _sessionsAfter(ParkingSession created) async {
    try {
      return await _repository.listOpenSessions();
    } on Failure {
      return [created, ...state.sessions.where((s) => s.id != created.id)];
    }
  }
}
