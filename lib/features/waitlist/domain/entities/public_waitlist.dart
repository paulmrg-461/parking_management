import 'package:equatable/equatable.dart';

import 'waitlist_entry.dart';

/// What the public card knows before the customer types anything.
class PublicWaitlistInfo extends Equatable {
  const PublicWaitlistInfo({
    required this.enabled,
    required this.claimMinutes,
    required this.notifyChannel,
    this.waitingByCategory = const {},
  });

  final bool enabled;
  final int claimMinutes;
  final WaitlistChannel notifyChannel;

  /// People waiting per category id.
  final Map<int, int> waitingByCategory;

  int waitingFor(int categoryId) => waitingByCategory[categoryId] ?? 0;

  factory PublicWaitlistInfo.fromJson(Map<String, dynamic> json) {
    final waiting = <int, int>{};
    final raw = json['waiting'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final categoryId = (item['category_id'] as num?)?.toInt();
        if (categoryId != null) {
          waiting[categoryId] = (item['count'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return PublicWaitlistInfo(
      enabled: json['enabled'] == true,
      claimMinutes: (json['claim_minutes'] as num?)?.toInt() ?? 15,
      notifyChannel: waitlistChannelFrom(json['notify_channel'] as String?),
      waitingByCategory: waiting,
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    claimMinutes,
    notifyChannel,
    waitingByCategory,
  ];
}

/// The customer's own turn: the join answer plus the live status.
class PublicWaitlistEntry extends Equatable {
  const PublicWaitlistEntry({
    required this.id,
    required this.plate,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    required this.position,
    required this.waitUntil,
    required this.holdMinutes,
    required this.claimMinutes,
    required this.notifyChannel,
    this.offerUntil,
    this.reservationId,
    this.lotName = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
  });

  final int id;
  final String plate;
  final int categoryId;
  final String categoryName;
  final WaitlistStatus status;
  final int position;
  final DateTime waitUntil;
  final int holdMinutes;
  final int claimMinutes;
  final WaitlistChannel notifyChannel;
  final DateTime? offerUntil;
  final int? reservationId;
  final String lotName;
  final String address;
  final String phone;
  final String whatsapp;

  bool get isWaiting => status == WaitlistStatus.waiting;
  bool get isOffered => status == WaitlistStatus.offered;
  bool get isClaimed => status == WaitlistStatus.claimed;

  /// The turn is over and the customer may join again.
  bool get isFinished =>
      status == WaitlistStatus.expired ||
      status == WaitlistStatus.left ||
      status == WaitlistStatus.cancelled;

  factory PublicWaitlistEntry.fromJson(Map<String, dynamic> json) {
    DateTime parse(Object? raw) => raw is String
        ? DateTime.tryParse(raw)?.toLocal() ?? DateTime(1970)
        : DateTime(1970);
    final lot = json['lot'] is Map
        ? Map<String, dynamic>.from(json['lot'] as Map)
        : const <String, dynamic>{};
    return PublicWaitlistEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      plate: json['plate'] as String? ?? '',
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      status: waitlistStatusFrom(json['status'] as String?),
      position: (json['position'] as num?)?.toInt() ?? 0,
      waitUntil: parse(json['wait_until']),
      holdMinutes: (json['hold_minutes'] as num?)?.toInt() ?? 60,
      claimMinutes: (json['claim_minutes'] as num?)?.toInt() ?? 15,
      notifyChannel: waitlistChannelFrom(json['notify_channel'] as String?),
      offerUntil: json['offer_until'] == null
          ? null
          : parse(json['offer_until']),
      reservationId: (json['reservation_id'] as num?)?.toInt(),
      lotName: lot['name'] as String? ?? '',
      address: lot['address'] as String? ?? '',
      phone: lot['phone'] as String? ?? '',
      whatsapp: lot['whatsapp'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    plate,
    categoryId,
    categoryName,
    status,
    position,
    waitUntil,
    holdMinutes,
    claimMinutes,
    notifyChannel,
    offerUntil,
    reservationId,
    lotName,
    address,
    phone,
    whatsapp,
  ];
}
