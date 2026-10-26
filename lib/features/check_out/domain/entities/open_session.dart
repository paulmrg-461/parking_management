import 'package:equatable/equatable.dart';

/// A currently-open parking session, as returned by the check-ins list.
/// Status is always "open" for this list, so it isn't modeled here.
class OpenSession extends Equatable {
  const OpenSession({
    required this.id,
    required this.vehicleId,
    required this.entryTime,
    this.hasPass = false,
  });

  final int id;
  final int vehicleId;
  final DateTime entryTime;

  /// The vehicle has an active monthly pass right now (`has_pass` in the
  /// view), so the check-out will not charge the stay.
  final bool hasPass;

  @override
  List<Object?> get props => [id, vehicleId, entryTime, hasPass];
}
