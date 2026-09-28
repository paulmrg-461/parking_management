import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/core/sync/pending_photo_storage.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_mutation_replayer.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';

class _FakeRemote implements CheckInRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  String? plate;
  List<XFile>? photos;
  NewVehicleInfo? newVehicle;
  String? idempotencyKey;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    String? idempotencyKey,
  }) async {
    this.plate = plate;
    this.photos = photos;
    this.newVehicle = newVehicle;
    this.idempotencyKey = idempotencyKey;
    if (error != null) {
      throw error!;
    }
    return ParkingSession(
      id: 1,
      plate: plate,
      status: ParkingSessionStatus.open,
      entryTime: DateTime(2026, 1, 1),
      photoCount: photos.length,
    );
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => const [];
}

class _FakePhotos implements PendingPhotoStorage {
  final List<String> deleted = [];

  @override
  Future<void> deleteFor(String clientRef) async => deleted.add(clientRef);

  @override
  Future<List<String>> persist({
    required String clientRef,
    required List<XFile> photos,
  }) async => throw UnimplementedError();

  @override
  Future<List<XFile>> load(List<String> refs) async => [
    for (final ref in refs) XFile(ref),
  ];
}

PendingMutation _queued(String payload) => PendingMutation(
  entityType: MutationEntity.checkIn,
  operation: MutationOperation.create,
  entityId: null,
  payloadJson: payload,
  enqueuedAt: DateTime.utc(2026, 1, 1),
);

const _withVehicle =
    '{"plate":"XYZ999","photo_paths":["/tmp/a.jpg"],"client_entry_time":"2026-01-01T00:00:00.000","client_ref":"ref-2","category_id":2,"color":"Blue","brand":null}';

void main() {
  test('Success: replays plate/photos/new vehicle with Idempotency-Key and cleans photos', () async {
    final remote = _FakeRemote();
    final photos = _FakePhotos();

    await CheckInMutationReplayer(remote, photos).replay(_queued(_withVehicle));

    expect(remote.plate, 'XYZ999');
    expect(remote.photos!.single.path, '/tmp/a.jpg');
    expect(
      remote.newVehicle,
      const NewVehicleInfo(categoryId: 2, color: 'Blue'),
    );
    expect(remote.idempotencyKey, 'ref-2');
    expect(photos.deleted, ['ref-2']);
  });

  test(
    'Failure: a failing replay propagates and keeps the persisted photos',
    () async {
      final remote = _FakeRemote(const NetworkFailure('offline'));
      final photos = _FakePhotos();

      await expectLater(
        CheckInMutationReplayer(remote, photos).replay(_queued(_withVehicle)),
        throwsA(isA<NetworkFailure>()),
      );
      expect(photos.deleted, isEmpty);
    },
  );

  test(
    'Security: discarding a dead letter deletes its evidence photos',
    () async {
      final photos = _FakePhotos();

      await CheckInMutationReplayer(
        _FakeRemote(),
        photos,
      ).discard(_queued(_withVehicle));

      expect(photos.deleted, ['ref-2']);
    },
  );
}
