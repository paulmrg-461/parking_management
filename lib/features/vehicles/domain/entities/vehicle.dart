import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  const Vehicle({
    this.id,
    required this.plate,
    required this.categoryId,
    this.color,
    this.brand,
    this.ownerPhone,
    this.ownerName,
  });

  final int? id;
  final String plate;
  final int categoryId;
  final String? color;
  final String? brand;

  /// Customer phone for WhatsApp notices (set from the vehicle history).
  final String? ownerPhone;

  /// Optional full name of the owner, useful for passes or left keys.
  final String? ownerName;

  @override
  List<Object?> get props => [
    id,
    plate,
    categoryId,
    color,
    brand,
    ownerPhone,
    ownerName,
  ];
}
