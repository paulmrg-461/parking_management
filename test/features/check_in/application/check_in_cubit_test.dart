import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_in/application/create_check_in.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({this.sessionToReturn, this.error});

  final ParkingSession? sessionToReturn;
  final Failure? error;
  Failure? listError;
  List<ParkingSession> open = const [];
  bool createCheckInCalled = false;
  NewVehicleInfo? lastNewVehicle;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    createCheckInCalled = true;
    lastNewVehicle = newVehicle;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return sessionToReturn!;
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async =>
      listError == null ? open : throw listError!;
}

CheckInCubit _cubit(_FakeCheckInRepository repository) =>
    CheckInCubit(CreateCheckIn(repository), repository);

void main() {
  final session = ParkingSession(
    id: 1,
    plate: 'ABC123',
    status: ParkingSessionStatus.open,
    entryTime: DateTime(2026, 1, 1),
    photoCount: 2,
  );

  test(
    'Success: submit reports success and refreshes the open sessions',
    () async {
      final repository = _FakeCheckInRepository(sessionToReturn: session)
        ..open = [session];
      final cubit = _cubit(repository);

      await cubit.submitCheckIn(plate: 'abc123', photos: const []);

      expect(
        cubit.state.submission,
        SubmissionSucceeded<ParkingSession>(session),
      );
      expect(cubit.state.sessions, [session]);
      expect(cubit.state.status, SessionsStatus.loaded);
    },
  );

  test(
    'Success: submitCheckIn forwards new-vehicle data to the repository',
    () async {
      final repository = _FakeCheckInRepository(sessionToReturn: session);
      const info = NewVehicleInfo(categoryId: 2, color: 'Blue', brand: 'Kia');

      await _cubit(repository)
          .submitCheckIn(plate: 'abc123', photos: const [], newVehicle: info);

      expect(repository.lastNewVehicle, info);
    },
  );

  test(
    'Success: an offline (queued) check-in is shown even if refresh fails',
    () async {
      final pending = ParkingSession(
        id: -5,
        plate: 'ABC123',
        status: ParkingSessionStatus.pendingSync,
        entryTime: DateTime(2026),
        photoCount: 0,
      );
      final repository = _FakeCheckInRepository(sessionToReturn: pending)
        ..listError = const NetworkFailure('offline');
      final cubit = _cubit(repository);

      await cubit.submitCheckIn(plate: 'ABC123', photos: const []);

      expect(cubit.state.sessions, [pending]);
    },
  );

  test(
    'Failure: a failed submit keeps the sessions list and reports the error',
    () async {
      final repository = _FakeCheckInRepository(
        error: const ValidationFailure('Vehicle already has an open session'),
      )..open = [session];
      final cubit = _cubit(repository);
      await cubit.loadOpenSessions();

      await cubit.submitCheckIn(plate: 'ABC123', photos: const []);

      expect(cubit.state.sessions, [session]);
      expect(
        cubit.state.submission,
        const SubmissionFailed('Vehicle already has an open session'),
      );
    },
  );

  test(
    'Failure: a failed load is reported without blocking check-in',
    () async {
      final repository = _FakeCheckInRepository(sessionToReturn: session)
        ..listError = const NetworkFailure('offline');
      final cubit = _cubit(repository);

      await cubit.loadOpenSessions();

      expect(cubit.state.status, SessionsStatus.failure);
      expect(cubit.state.loadError, 'offline');
      expect(cubit.state.submission, const SubmissionIdle());
    },
  );

  test(
    'Security: an empty plate is rejected before hitting the repository',
    () async {
      final repository = _FakeCheckInRepository(sessionToReturn: session);
      final cubit = _cubit(repository);

      await cubit.submitCheckIn(plate: '   ', photos: const []);

      expect(cubit.state.submission, isA<SubmissionFailed>());
      expect(repository.createCheckInCalled, isFalse);
    },
  );
}
