import 'package:equatable/equatable.dart';

enum ParkingSessionStatus { open, closed, pendingSync }

class ParkingSession extends Equatable {
  const ParkingSession({
    required this.id,
    required this.plate,
    required this.status,
    required this.entryTime,
    required this.photoCount,
    this.leftKeys = false,
    this.spotId,
    this.spotCode,
    this.videoCount = 0,
  });

  final int id;
  final String plate;
  final ParkingSessionStatus status;
  final DateTime entryTime;
  final int photoCount;

  /// The customer left the keys at the desk.
  final bool leftKeys;

  /// Physical bay assigned by the server (map sites only).
  final int? spotId;
  final String? spotCode;

  /// Optional walk-around evidence video attached at check-in.
  final int videoCount;

  @override
  List<Object?> get props => [
    id,
    plate,
    status,
    entryTime,
    photoCount,
    leftKeys,
    spotId,
    spotCode,
    videoCount,
  ];
}
