import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';

class _FakeCheckInRepository implements CheckInRepository {
  _FakeCheckInRepository({this.sessionToReturn, this.error});

  final ParkingSession? sessionToReturn;
  final Failure? error;
  bool createCheckInCalled = false;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  }) async {
    createCheckInCalled = true;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return sessionToReturn!;
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => const [];
}

void main() {
  final session = ParkingSession(
    id: 1,
    plate: 'ABC123',
    status: ParkingSessionStatus.open,
    entryTime: DateTime(2026, 1, 1),
    photoCount: 2,
  );

  test('Success: submitCheckIn emits CheckInSuccess with the created session', () async {
    final cubit = CheckInCubit(_FakeCheckInRepository(sessionToReturn: session));

    await cubit.submitCheckIn(plate: 'abc123', photos: const []);

    expect(cubit.state, CheckInSuccess(session));
  });

  test(
    'Failure: submitCheckIn emits CheckInFailure when the repository throws NetworkFailure',
    () async {
      final cubit = CheckInCubit(
        _FakeCheckInRepository(error: const NetworkFailure('offline')),
      );

      await cubit.submitCheckIn(plate: 'ABC123', photos: const []);

      expect(cubit.state, const CheckInFailure('offline'));
    },
  );

  test(
    'Security: submitCheckIn rejects an empty/whitespace-only plate before hitting the repository',
    () async {
      final repository = _FakeCheckInRepository(sessionToReturn: session);
      final cubit = CheckInCubit(repository);

      await cubit.submitCheckIn(plate: '   ', photos: const []);

      expect(cubit.state, isA<CheckInFailure>());
      expect(repository.createCheckInCalled, isFalse);
    },
  );
}
