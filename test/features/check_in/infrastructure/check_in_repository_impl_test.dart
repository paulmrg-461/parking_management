import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_photo_storage.dart';
import 'package:parking_management/features/auth/domain/entities/auth_session.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_repository_impl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_sync_outbox.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._supportPath);

  final String _supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;
}

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

  late Directory supportDir;
  late Directory sourceDir;

  setUp(() async {
    supportDir = await Directory.systemTemp.createTemp('check_in_repo_support');
    sourceDir = await Directory.systemTemp.createTemp('check_in_repo_source');
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);
  });

  tearDown(() async {
    await supportDir.delete(recursive: true);
    await sourceDir.delete(recursive: true);
  });

  File sourcePhoto(String name, String content) {
    final file = File(path.join(sourceDir.path, name));
    file.writeAsStringSync(content);
    return file;
  }

  test('Success: createCheckIn returns the remote-mapped ParkingSession', () async {
    final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
    final remote = _FakeRemote(sessionToReturn: session);
    final repository = CheckInRepositoryImpl(auth, remote, FakeSyncOutbox(), PendingPhotoStorage());

    final result = await repository.createCheckIn(plate: 'ABC123', photos: const []);

    expect(result, session);
    expect(remote.tokenUsed, 'token-1');
  });

  test(
    'Failure: NetworkFailure persists photos, queues a checkIn/create mutation, and returns an optimistic pending session',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckInRepositoryImpl(auth, remote, outbox, PendingPhotoStorage());
      final photo = sourcePhoto('evidence.jpg', 'evidence-bytes');

      final result = await repository.createCheckIn(plate: 'ABC123', photos: [photo]);

      expect(result.status, ParkingSessionStatus.pendingSync);
      expect(result.plate, 'ABC123');
      expect(result.id, lessThan(0));
      expect(result.photoCount, 1);

      expect(outbox.enqueued, hasLength(1));
      expect(outbox.enqueued.single.entityType, 'checkIn');
      expect(outbox.enqueued.single.operation, 'create');
      expect(outbox.enqueued.single.entityId, isNull);

      final payload = jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
      expect(payload['plate'], 'ABC123');
      expect(payload['client_entry_time'], isNotNull);
      expect(payload['client_ref'], isNotEmpty);
      final persistedPaths = (payload['photo_paths'] as List<dynamic>).cast<String>();
      expect(persistedPaths, hasLength(1));
      expect(File(persistedPaths.single).existsSync(), isTrue);
    },
  );

  test(
    'Security/robustness: persisted photo bytes survive deletion of the original transient file',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckInRepositoryImpl(auth, remote, outbox, PendingPhotoStorage());
      final photo = sourcePhoto('evidence.jpg', 'evidence-bytes');

      await repository.createCheckIn(plate: 'ABC123', photos: [photo]);
      await photo.delete();

      final payload = jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
      final persistedPath = (payload['photo_paths'] as List<dynamic>).cast<String>().single;

      expect(photo.existsSync(), isFalse);
      expect(File(persistedPath).existsSync(), isTrue);
      expect(File(persistedPath).readAsStringSync(), 'evidence-bytes');
    },
  );

  test(
    'Failure: a non-network failure still propagates un-queued',
    () async {
      final auth = FakeAuthRepository(sessionToRestore: authenticatedSession());
      final remote = _FakeRemote(error: const ValidationFailure('Invalid plate'));
      final outbox = FakeSyncOutbox();
      final repository = CheckInRepositoryImpl(auth, remote, outbox, PendingPhotoStorage());

      await expectLater(
        repository.createCheckIn(plate: 'ABC123', photos: const []),
        throwsA(isA<ValidationFailure>()),
      );
      expect(outbox.enqueued, isEmpty);
    },
  );

  test(
    'Security: missing token throws AuthenticationFailure before any network call',
    () async {
      final auth = FakeAuthRepository();
      final remote = _FakeRemote(sessionToReturn: session);
      final repository = CheckInRepositoryImpl(auth, remote, FakeSyncOutbox(), PendingPhotoStorage());

      expect(
        () => repository.createCheckIn(plate: 'ABC123', photos: const []),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(remote.tokenUsed, isNull);
    },
  );
}
