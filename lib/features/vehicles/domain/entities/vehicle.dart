import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  const Vehicle({
    this.id,
    required this.plate,
    required this.categoryId,
    this.color,
    this.brand,
  });

  final int? id;
  final String plate;
  final int categoryId;
  final String? color;
  final String? brand;

  @override
  List<Object?> get props => [id, plate, categoryId, color, brand];
}
