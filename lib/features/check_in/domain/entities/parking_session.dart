import 'package:equatable/equatable.dart';

enum ParkingSessionStatus { open, closed, pendingSync }

class ParkingSession extends Equatable {
  const ParkingSession({
    required this.id,
    required this.plate,
    required this.status,
    required this.entryTime,
    required this.photoCount,
  });

  final int id;
  final String plate;
  final ParkingSessionStatus status;
  final DateTime entryTime;
  final int photoCount;

  @override
  List<Object?> get props => [id, plate, status, entryTime, photoCount];
}
