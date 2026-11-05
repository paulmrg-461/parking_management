import 'package:equatable/equatable.dart';

/// A currently-open parking session, as returned by the check-ins list.
/// Status is always "open" for this list, so it isn't modeled here.
class OpenSession extends Equatable {
  const OpenSession({
    required this.id,
    required this.vehicleId,
    required this.entryTime,
    this.plate = '',
    this.hasPass = false,
    this.photoCount = 0,
    this.leftKeys = false,
  });

  final int id;
  final int vehicleId;
  final DateTime entryTime;

  /// Plate from `open_sessions_view`, so lists never need a vehicles lookup.
  final String plate;

  /// The vehicle has an active monthly pass right now (`has_pass` in the
  /// view), so the check-out will not charge the stay.
  final bool hasPass;

  /// Evidence photos taken at check-in, for reprinting the entry ticket.
  final int photoCount;

  /// The customer left the keys at the desk.
  final bool leftKeys;

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    entryTime,
    plate,
    hasPass,
    photoCount,
    leftKeys,
  ];
}
