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
    this.version = 0,
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

  /// Row version from the server (`0` when unknown, e.g. an old cache entry);
  /// offline edits send it back so a concurrent change is a conflict, not an
  /// overwrite.
  final int version;

  @override
  List<Object?> get props => [
    id,
    plate,
    categoryId,
    color,
    brand,
    ownerPhone,
    ownerName,
    version,
  ];
}
