import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_repository_impl.dart';

import '../../../helpers/fake_auth_repository.dart';

class _FakeRemote implements CheckInRemoteDataSource {
  _FakeRemote({this.sessionToReturn, this.error});

  final ParkingSession? sessionToReturn;
  final Failure? error;
  String? tokenUsed;

  @override
  Future<ParkingSession> createCheckIn(
    String token, {
    required String plate,
    required List<File> photos,
  }) async {
    tokenUsed = token;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return sessionToReturn!;
  }

  @override
  Future<List<ParkingSession>> listOpenSessions(String token) async {
    tokenUsed = token;
    return const [];
  }
}

void main() {
  final session = ParkingSession(
    id: 1,
    plate: 'ABC123',
    status: ParkingSessionStatus.open,
    entryTime: DateTime(2026, 1, 1),
    photoCount: 0,
  );

  AuthSession authenticatedSession() => const AuthSession(
        user: User(id: 1, username: 'op', displayName: 'Op', role: UserRole.operator),
        token: 'token-1',
      );

  test('Success: createCheckIn returns the remote-mapped ParkingSession', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(sessionToReturn: session);
    final repository = CheckInRepositoryImpl(auth, remote);

    final result = await repository.createCheckIn(plate: 'ABC123', photos: const []);

    expect(result, session);
    expect(remote.tokenUsed, 'token-1');
  });

  test('Failure: createCheckIn rethrows the failure raised by the remote source', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final repository = CheckInRepositoryImpl(auth, remote);

    expect(
      () => repository.createCheckIn(plate: 'ABC123', photos: const []),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final auth = FakeAuthRepository();
      final remote = _FakeRemote(sessionToReturn: session);
      final repository = CheckInRepositoryImpl(auth, remote);

      expect(
        () => repository.createCheckIn(plate: 'ABC123', photos: const []),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(remote.tokenUsed, isNull);
    },
  );
}
