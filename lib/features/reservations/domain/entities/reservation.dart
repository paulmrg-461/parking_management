import 'package:equatable/equatable.dart';

/// A capacity hold for a plate in a category. Active reservations count
/// against the category capacity until the car checks in, the hold is
/// cancelled or it expires.
class Reservation extends Equatable {
  const Reservation({
    required this.id,
    required this.plate,
    required this.categoryId,
    required this.reservedUntil,
    this.categoryName = '',
    this.status = 'active',
    this.notes,
  });

  final int id;
  final String plate;
  final int categoryId;
  final String categoryName;
  final DateTime reservedUntil;
  final String status;
  final String? notes;

  bool get isExpired => reservedUntil.isBefore(DateTime.now());

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final category = json['categories'];
    return Reservation(
      id: (json['id'] as num).toInt(),
      plate: json['plate'] as String,
      categoryId: (json['category_id'] as num).toInt(),
      categoryName: category is Map<String, dynamic>
          ? category['name'] as String? ?? ''
          : '',
      reservedUntil: DateTime.parse(json['reserved_until'] as String),
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, plate, categoryId, categoryName, reservedUntil, status, notes];
}
