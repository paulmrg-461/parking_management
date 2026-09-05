import 'dart:io';

import '../entities/parking_session.dart';

abstract class CheckInRepository {
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<File> photos,
  });

  Future<List<ParkingSession>> listOpenSessions();
}
