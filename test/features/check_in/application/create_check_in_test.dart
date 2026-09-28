import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_in/application/create_check_in.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/evidence_policy.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';

class _FakeRepository implements CheckInRepository {
  String? plate;
  List<XFile>? photos;
  NewVehicleInfo? newVehicle;

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    this.plate = plate;
    this.photos = photos;
    this.newVehicle = newVehicle;
    return ParkingSession(
      id: 1,
      plate: plate,
      status: ParkingSessionStatus.open,
      entryTime: DateTime.utc(2026),
      photoCount: photos.length,
    );
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => const [];
}

XFile _photo(int bytes) => XFile.fromData(Uint8List(bytes), path: 'p.jpg');

void main() {
  late _FakeRepository repository;
  late CreateCheckIn createCheckIn;

  setUp(() {
    repository = _FakeRepository();
    createCheckIn = CreateCheckIn(repository);
  });

  test(
    'Success: normalizes the plate and forwards photos and vehicle data',
    () async {
      const info = NewVehicleInfo(categoryId: 2);
      final photos = [_photo(10), _photo(20)];

      final session = await createCheckIn(
        plate: ' abc 123 ',
        photos: photos,
        newVehicle: info,
      );

      expect(session.plate, 'ABC123');
      expect(repository.photos, photos);
      expect(repository.newVehicle, info);
    },
  );

  test(
    'Failure: more than the allowed photos is rejected before any upload',
    () async {
      final photos = List.generate(
        EvidencePolicy.maxPhotos + 1,
        (_) => _photo(1),
      );

      await expectLater(
        createCheckIn(plate: 'ABC123', photos: photos),
        throwsA(isA<ValidationFailure>()),
      );
      expect(repository.plate, isNull);
    },
  );

  test(
    'Security: an oversized photo or empty plate never reaches the repository',
    () async {
      await expectLater(
        createCheckIn(
          plate: 'ABC123',
          photos: [_photo(EvidencePolicy.maxPhotoBytes + 1)],
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        createCheckIn(plate: '   ', photos: const []),
        throwsA(isA<ValidationFailure>()),
      );
      expect(repository.plate, isNull);
    },
  );
}
