import 'package:equatable/equatable.dart';

import '../../../check_out/domain/entities/occupancy_forecast.dart';

/// One vehicle category with its public availability (`rpc/public_availability`).
class PublicCategoryAvailability extends Equatable {
  const PublicCategoryAvailability({
    required this.id,
    required this.name,
    required this.group,
    this.categoryCapacity = 0,
    this.groupCapacity = 0,
    this.occupied = 0,
    this.reserved = 0,
    this.hourlyAmount = 0,
    this.available,
  });

  final int id;
  final String name;

  /// `car`, `moto` or `heavy` (drives the icon and the copy).
  final String group;
  final int categoryCapacity;
  final int groupCapacity;
  final int occupied;
  final int reserved;

  /// Active hourly tariff in minor units (`0` when the lot has not set one).
  final int hourlyAmount;

  bool get hasPrice => hourlyAmount > 0;

  /// `null` means unlimited (no category or group cap configured).
  final int? available;

  bool get isUnlimited => available == null;
  bool get isFull => available != null && available! <= 0;

  /// Effective cap for the progress bar (`0` when unlimited).
  int get capacity => groupCapacity > 0
      ? (categoryCapacity > 0
            ? (categoryCapacity < groupCapacity
                  ? categoryCapacity
                  : groupCapacity)
            : groupCapacity)
      : categoryCapacity;

  factory PublicCategoryAvailability.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return PublicCategoryAvailability(
      id: value(json['id']),
      name: json['name'] as String? ?? '',
      group: json['group'] as String? ?? 'heavy',
      categoryCapacity: value(json['category_capacity']),
      groupCapacity: value(json['group_capacity']),
      occupied: value(json['occupied']),
      reserved: value(json['reserved']),
      hourlyAmount: value(json['hourly_amount']),
      available: json['available'] == null ? null : value(json['available']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    group,
    categoryCapacity,
    groupCapacity,
    occupied,
    reserved,
    hourlyAmount,
    available,
  ];
}

/// Site identity + categories shown on the public booking page.
/// "When does it fill up?" for the public page: aggregates only (levels,
/// deadline, confidence), never counts, capacities or sessions.
class PublicForecast extends Equatable {
  const PublicForecast({required this.status, this.groups = const []});

  final ForecastStatus status;
  final List<PublicForecastGroup> groups;

  static const hidden = PublicForecast(status: ForecastStatus.unavailable);

  bool get isVisible => status == ForecastStatus.ok && groups.isNotEmpty;

  factory PublicForecast.fromJson(Object? raw) {
    if (raw is! Map) {
      return PublicForecast.hidden;
    }
    final json = Map<String, dynamic>.from(raw);
    final status = forecastStatusFrom(json['status'] as String?);
    if (status != ForecastStatus.ok) {
      return PublicForecast(status: status);
    }
    final groups = json['groups'];
    return PublicForecast(
      status: status,
      groups: groups is! List
          ? const []
          : [
              for (final item in groups)
                if (item is Map)
                  PublicForecastGroup.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
            ],
    );
  }

  @override
  List<Object?> get props => [status, groups];
}

class PublicForecastGroup extends Equatable {
  const PublicForecastGroup({
    required this.group,
    required this.confidence,
    required this.fullNow,
    required this.hours,
    this.fullAt,
  });

  final String group;
  final ForecastConfidence confidence;
  final bool fullNow;
  final String? fullAt;
  final List<PublicForecastHour> hours;

  factory PublicForecastGroup.fromJson(Map<String, dynamic> json) {
    final hours = json['hours'];
    return PublicForecastGroup(
      group: json['group'] as String? ?? '',
      confidence: forecastConfidenceFrom(json['confidence'] as String?),
      fullNow: json['full_now'] == true,
      fullAt: json['full_at'] as String?,
      hours: hours is! List
          ? const []
          : [
              for (final item in hours)
                if (item is Map)
                  PublicForecastHour(
                    hour: (item['hour'] as num?)?.toInt() ?? 0,
                    level: forecastLevelFrom(item['level'] as String?),
                  ),
            ],
    );
  }

  @override
  List<Object?> get props => [group, confidence, fullNow, fullAt, hours];
}

class PublicForecastHour extends Equatable {
  const PublicForecastHour({required this.hour, required this.level});

  final int hour;
  final ForecastLevel level;

  @override
  List<Object?> get props => [hour, level];
}

class PublicBookingAvailability extends Equatable {
  const PublicBookingAvailability({
    required this.lotId,
    required this.lotName,
    this.address = '',
    this.schedule = '',
    this.phone = '',
    this.whatsapp = '',
    this.logoUrl,
    this.coverUrl,
    this.timezone = 'America/Bogota',
    this.currency = 'COP',
    this.maxReservationHours = 24,
    this.categories = const [],
    this.forecast = PublicForecast.hidden,
  });

  final int lotId;
  final String lotName;
  final String address;
  final String schedule;
  final String phone;
  final String whatsapp;
  final String? logoUrl;

  /// Wide banner for the hero (null when the lot has no cover).
  final String? coverUrl;
  final String timezone;
  final String currency;
  final int maxReservationHours;
  final List<PublicCategoryAvailability> categories;

  /// "When does it fill up?" (aggregates only, `hidden` on older backends).
  final PublicForecast forecast;

  bool get hasAvailability => categories.any((category) => !category.isFull);

  factory PublicBookingAvailability.fromJson(
    Map<String, dynamic> json, {
    String? logoUrl,
    String? coverUrl,
  }) {
    final lot = json['lot'] is Map
        ? Map<String, dynamic>.from(json['lot'] as Map)
        : const <String, dynamic>{};
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return PublicBookingAvailability(
      lotId: value(lot['id']),
      lotName: lot['name'] as String? ?? '',
      address: lot['address'] as String? ?? '',
      schedule: lot['schedule'] as String? ?? '',
      phone: lot['phone'] as String? ?? '',
      whatsapp: lot['whatsapp'] as String? ?? '',
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      timezone: lot['timezone'] as String? ?? 'America/Bogota',
      currency: lot['currency'] as String? ?? 'COP',
      maxReservationHours: value(json['max_reservation_hours']),
      categories: [
        for (final item in (json['categories'] as List<dynamic>? ?? const []))
          PublicCategoryAvailability.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
      forecast: PublicForecast.fromJson(json['forecast']),
    );
  }

  @override
  List<Object?> get props => [
    lotId,
    lotName,
    address,
    schedule,
    phone,
    whatsapp,
    logoUrl,
    coverUrl,
    timezone,
    currency,
    maxReservationHours,
    categories,
    forecast,
  ];
}

/// Confirmed public hold (`rpc/public_create_reservation`).
class PublicReservation extends Equatable {
  const PublicReservation({
    required this.id,
    required this.plate,
    required this.categoryName,
    required this.reservedUntil,
    this.lotName = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
  });

  final int id;
  final String plate;
  final String categoryName;
  final DateTime reservedUntil;
  final String lotName;
  final String address;
  final String phone;
  final String whatsapp;

  factory PublicReservation.fromJson(Map<String, dynamic> json) {
    final lot = json['lot'] is Map
        ? Map<String, dynamic>.from(json['lot'] as Map)
        : const <String, dynamic>{};
    final rawUntil = json['reserved_until'];
    return PublicReservation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      plate: json['plate'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      reservedUntil: rawUntil is String
          ? DateTime.tryParse(rawUntil)?.toLocal() ?? DateTime(1970)
          : DateTime(1970),
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
    categoryName,
    reservedUntil,
    lotName,
    address,
    phone,
    whatsapp,
  ];
}
