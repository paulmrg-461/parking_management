import 'package:cross_file/cross_file.dart';

import '../../../core/error/failure.dart';
import '../../plate_scanning/domain/normalize_plate.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import '../domain/evidence_policy.dart';
import '../domain/repositories/check_in_repository.dart';

/// Use case: validates a check-in (plate format, evidence limits) before it
/// is sent or queued, so an invalid request never reaches the outbox.
class CreateCheckIn {
  CreateCheckIn(this._repository);

  final CheckInRepository _repository;

  Future<ParkingSession> call({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    final normalized = normalizePlate(plate);
    await _validatePhotos(photos);
    return _repository.createCheckIn(
      plate: normalized,
      photos: photos,
      newVehicle: newVehicle,
    );
  }

  Future<void> _validatePhotos(List<XFile> photos) async {
    if (photos.length > EvidencePolicy.maxPhotos) {
      throw const ValidationFailure(
        'At most ${EvidencePolicy.maxPhotos} photos per check-in',
        ClientFailureCodes.tooManyPhotos,
      );
    }
    for (final photo in photos) {
      if (await photo.length() > EvidencePolicy.maxPhotoBytes) {
        throw const ValidationFailure(
          'Each photo must be 5 MB or smaller',
          ClientFailureCodes.photoTooLarge,
        );
      }
    }
  }
}
