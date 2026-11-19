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
    this.customerName,
    this.customerPhone,
    this.source = 'app',
    this.inGrace = false,
  });

  final int id;
  final String plate;
  final int categoryId;
  final String categoryName;
  final DateTime reservedUntil;
  final String status;
  final String? notes;

  /// Whoever booked from the public page (null for an operator hold).
  final String? customerName;
  final String? customerPhone;

  /// `app` (front desk) or `public` (the customer booked it themselves).
  final String source;

  bool get isPublic => source == 'public';

  /// An unclaimed waitlist offer: a real hold created by the queue.
  bool get isWaitlistOffer => source == 'waitlist';

  String? get _phone => switch (customerPhone?.trim()) {
    final phone? when phone.isNotEmpty => phone,
    _ => null,
  };

  bool get hasContact =>
      _phone != null || (customerName?.trim().isNotEmpty ?? false);

  /// Name and phone on one line for the list (`null` when there is neither).
  String? get contactLine {
    final name = customerName?.trim();
    final phone = _phone;
    final parts = [if (name != null && name.isNotEmpty) name, ?phone];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Holds that lapse within this window are flagged on the list.
  static const expiringWindow = Duration(hours: 2);

  bool get isExpired => isExpiredAt(DateTime.now());

  bool isExpiredAt(DateTime now) => !reservedUntil.isAfter(now);

  /// Past its time but still inside the grace window. Decided by the server
  /// (`list_active_reservations`, which knows `reservation_grace()`), so the
  /// app never keeps a second copy of the rule.
  final bool inGrace;

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
      // `list_active_reservations` flattens the name; the table select used
      // to nest it under `categories`.
      categoryName:
          json['category_name'] as String? ??
          (category is Map<String, dynamic>
              ? category['name'] as String? ?? ''
              : ''),
      reservedUntil: DateTime.parse(json['reserved_until'] as String),
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      source: json['source'] as String? ?? 'app',
      inGrace: json['in_grace'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    plate,
    categoryId,
    categoryName,
    reservedUntil,
    status,
    notes,
    customerName,
    customerPhone,
    source,
    inGrace,
  ];
}

/// Soonest expiry first, so the holds about to lapse are seen at the top.
/// Returns a new list (the state list is never mutated in place).
List<Reservation> sortedByExpiry(Iterable<Reservation> reservations) =>
    [...reservations]
      ..sort((a, b) => a.reservedUntil.compareTo(b.reservedUntil));
