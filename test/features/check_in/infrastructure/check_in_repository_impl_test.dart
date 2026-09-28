import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/file_pending_photo_storage.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_repository_impl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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
  NewVehicleInfo? newVehicleUsed;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    String? idempotencyKey,
  }) async {
    newVehicleUsed = newVehicle;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return sessionToReturn!;
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async {
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

  XFile sourcePhoto(String name, String content) {
    final file = File(path.join(sourceDir.path, name));
    file.writeAsStringSync(content);
    return XFile(file.path);
  }

  test(
    'Success: createCheckIn returns the remote-mapped ParkingSession',
    () async {
      final remote = _FakeRemote(sessionToReturn: session);
      final repository = CheckInRepositoryImpl(
        remote,
        FakeSyncOutbox(),
        FilePendingPhotoStorage(),
      );

      final result = await repository.createCheckIn(
        plate: 'ABC123',
        photos: const [],
      );

      expect(result, session);
    },
  );

  test(
    'Success: createCheckIn forwards new-vehicle data to the remote',
    () async {
      final remote = _FakeRemote(sessionToReturn: session);
      final repository = CheckInRepositoryImpl(
        remote,
        FakeSyncOutbox(),
        FilePendingPhotoStorage(),
      );
      const info = NewVehicleInfo(categoryId: 3, color: 'Red');

      await repository.createCheckIn(
        plate: 'ABC123',
        photos: const [],
        newVehicle: info,
      );

      expect(remote.newVehicleUsed, info);
    },
  );

  test(
    'Failure: offline check-in queues the new-vehicle fields in the payload',
    () async {
      final remote = _FakeRemote(error: const NetworkFailure('offline'));
      final outbox = FakeSyncOutbox();
      final repository = CheckInRepositoryImpl(
        remote,
        outbox,
        FilePendingPhotoStorage(),
      );
      const info = NewVehicleInfo(categoryId: 3, color: 'Red', brand: 'Kia');

      await repository.createCheckIn(
        plate: 'ABC123',
        photos: const [],
        newVehicle: info,
      );

      final payload = jsonDecode(
        outbox.enqueued.single.payloadJson!,
      ) as Map<String, dynamic>;
      expect(payload['category_id'], 3);
      expect(payload['color'], 'Red');
      expect(payload['brand'], 'Kia');
    },
  );

  test('Security: offline check-in without new-vehicle data queues no vehicle fields', () async {
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final outbox = FakeSyncOutbox();
    final repository = CheckInRepositoryImpl(
      remote,
      outbox,
      FilePendingPhotoStorage(),
    );

    await repository.createCheckIn(plate: 'ABC123', photos: const []);

    final payload =
        jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
    expect(payload.containsKey('category_id'), isFalse);
    expect(payload.containsKey('color'), isFalse);
    expect(payload.containsKey('brand'), isFalse);
  });

  test('Failure: NetworkFailure persists photos, queues a checkIn/create mutation, and returns an optimistic pending session', () async {
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final outbox = FakeSyncOutbox();
    final repository = CheckInRepositoryImpl(
      remote,
      outbox,
      FilePendingPhotoStorage(),
    );
    final photo = sourcePhoto('evidence.jpg', 'evidence-bytes');

    final result = await repository.createCheckIn(
      plate: 'ABC123',
      photos: [photo],
    );

    expect(result.status, ParkingSessionStatus.pendingSync);
    expect(result.plate, 'ABC123');
    expect(result.id, lessThan(0));
    expect(result.photoCount, 1);

    expect(outbox.enqueued, hasLength(1));
    expect(outbox.enqueued.single.entityType, MutationEntity.checkIn);
    expect(outbox.enqueued.single.operation, MutationOperation.create);
    expect(outbox.enqueued.single.entityId, isNull);

    final payload =
        jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
    expect(payload['plate'], 'ABC123');
    final entryTime = payload['client_entry_time'] as String;
    expect(entryTime, endsWith('Z'));
    expect(DateTime.parse(entryTime).isUtc, isTrue);
    expect(payload['client_ref'], isNotEmpty);
    final persistedPaths = (payload['photo_paths'] as List<dynamic>)
        .cast<String>();
    expect(persistedPaths, hasLength(1));
    expect(File(persistedPaths.single).existsSync(), isTrue);
  });

  test('Security/robustness: persisted photo bytes survive deletion of the original transient file', () async {
    final remote = _FakeRemote(error: const NetworkFailure('offline'));
    final outbox = FakeSyncOutbox();
    final repository = CheckInRepositoryImpl(
      remote,
      outbox,
      FilePendingPhotoStorage(),
    );
    final photo = sourcePhoto('evidence.jpg', 'evidence-bytes');

    await repository.createCheckIn(plate: 'ABC123', photos: [photo]);
    await File(photo.path).delete();

    final payload =
        jsonDecode(outbox.enqueued.single.payloadJson!) as Map<String, dynamic>;
    final persistedPath = (payload['photo_paths'] as List<dynamic>)
        .cast<String>()
        .single;

    expect(File(photo.path).existsSync(), isFalse);
    expect(File(persistedPath).existsSync(), isTrue);
    expect(File(persistedPath).readAsStringSync(), 'evidence-bytes');
  });

  test('Failure: a non-network failure still propagates un-queued', () async {
    final remote = _FakeRemote(error: const ValidationFailure('Invalid plate'));
    final outbox = FakeSyncOutbox();
    final repository = CheckInRepositoryImpl(
      remote,
      outbox,
      FilePendingPhotoStorage(),
    );

    await expectLater(
      repository.createCheckIn(plate: 'ABC123', photos: const []),
      throwsA(isA<ValidationFailure>()),
    );
    expect(outbox.enqueued, isEmpty);
  });

  test(
    'Security: an expired session (401) is rethrown, never queued offline',
    () async {
      final outbox = FakeSyncOutbox();
      final remote = _FakeRemote(
        error: const AuthenticationFailure('Invalid credentials'),
      );
      final repository = CheckInRepositoryImpl(
        remote,
        outbox,
        FilePendingPhotoStorage(),
      );

      await expectLater(
        repository.createCheckIn(plate: 'ABC123', photos: const []),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(outbox.enqueued, isEmpty);
    },
  );
}
