import 'package:equatable/equatable.dart';

/// Where a turn in the queue stands.
enum WaitlistStatus { waiting, offered, claimed, expired, left, cancelled }

WaitlistStatus waitlistStatusFrom(String? value) => switch (value) {
  'waiting' => WaitlistStatus.waiting,
  'offered' => WaitlistStatus.offered,
  'claimed' => WaitlistStatus.claimed,
  'left' => WaitlistStatus.left,
  'cancelled' => WaitlistStatus.cancelled,
  // An unknown value (a newer backend) is treated as finished, never as a
  // turn the desk could still serve.
  _ => WaitlistStatus.expired,
};

/// How the customer is told about the offer.
enum WaitlistChannel { whatsapp, screen }

WaitlistChannel waitlistChannelFrom(String? value) =>
    value == 'whatsapp' ? WaitlistChannel.whatsapp : WaitlistChannel.screen;

/// One desk row: a customer's turn in the queue.
class WaitlistEntry extends Equatable {
  const WaitlistEntry({
    required this.id,
    required this.plate,
    required this.categoryId,
    required this.categoryName,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.waitUntil,
    required this.holdMinutes,
    required this.position,
    required this.createdAt,
    this.offerUntil,
    this.reservationId,
  });

  final int id;
  final String plate;
  final int categoryId;
  final String categoryName;
  final String customerName;
  final String customerPhone;
  final WaitlistStatus status;
  final DateTime waitUntil;
  final int holdMinutes;

  /// Deadline of the current offer (`null` unless [isOffered]).
  final DateTime? offerUntil;
  final int? reservationId;

  /// 1-based place inside the group.
  final int position;
  final DateTime createdAt;

  bool get isOffered => status == WaitlistStatus.offered;

  /// "Name · 300 123 4567", the same shape the reservations board uses.
  String get contactLine =>
      customerName.isEmpty ? customerPhone : '$customerName · $customerPhone';

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) {
    DateTime parse(Object? raw) => raw is String
        ? DateTime.tryParse(raw)?.toLocal() ?? DateTime(1970)
        : DateTime(1970);
    return WaitlistEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      plate: json['plate'] as String? ?? '',
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      status: waitlistStatusFrom(json['status'] as String?),
      waitUntil: parse(json['wait_until']),
      holdMinutes: (json['hold_minutes'] as num?)?.toInt() ?? 60,
      offerUntil: json['offer_until'] == null
          ? null
          : parse(json['offer_until']),
      reservationId: (json['reservation_id'] as num?)?.toInt(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: parse(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    plate,
    categoryId,
    categoryName,
    customerName,
    customerPhone,
    status,
    waitUntil,
    holdMinutes,
    offerUntil,
    reservationId,
    position,
    createdAt,
  ];
}
