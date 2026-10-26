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

  /// Holds that lapse within this window are flagged on the list.
  static const expiringWindow = Duration(hours: 2);

  bool get isExpired => isExpiredAt(DateTime.now());

  bool isExpiredAt(DateTime now) => !reservedUntil.isAfter(now);

  /// About to lapse (but still holding capacity). Expired holds are not
  /// "soon": they are already gone.
  bool expiresSoon({DateTime? now, Duration window = expiringWindow}) {
    final current = now ?? DateTime.now();
    if (isExpiredAt(current)) {
      return false;
    }
    return reservedUntil.difference(current) <= window;
  }

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

/// Soonest expiry first, so the holds about to lapse are seen at the top.
/// Returns a new list (the state list is never mutated in place).
List<Reservation> sortedByExpiry(Iterable<Reservation> reservations) =>
    [...reservations]
      ..sort((a, b) => a.reservedUntil.compareTo(b.reservedUntil));
