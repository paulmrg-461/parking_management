import 'package:cross_file/cross_file.dart';

import '../entities/new_vehicle_info.dart';
import '../entities/parking_session.dart';

abstract class CheckInRepository {
  /// Opens a session for [plate]. [newVehicle] registers the vehicle when the
  /// plate is unknown to the backend; it is ignored for existing plates.
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  });

  Future<List<ParkingSession>> listOpenSessions();
}
