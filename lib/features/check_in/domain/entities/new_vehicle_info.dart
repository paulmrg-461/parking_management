import 'package:equatable/equatable.dart';

/// Data needed to register a not-yet-known vehicle as part of a check-in.
/// Sent alongside the plate; the backend ignores it for existing plates.
class NewVehicleInfo extends Equatable {
  const NewVehicleInfo({required this.categoryId, this.color, this.brand});

  final int categoryId;
  final String? color;
  final String? brand;

  @override
  List<Object?> get props => [categoryId, color, brand];
}
