import 'package:equatable/equatable.dart';

/// Confirms a pending entry. [plate] corrects a misread; [categoryId] is only
/// needed for an unregistered plate.
class ConfirmLprEntry extends Equatable {
  const ConfirmLprEntry({required this.eventId, this.plate, this.categoryId});

  final int eventId;
  final String? plate;
  final int? categoryId;

  @override
  List<Object?> get props => [eventId, plate, categoryId];
}
