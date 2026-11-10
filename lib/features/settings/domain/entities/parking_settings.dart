import 'package:equatable/equatable.dart';

/// Singleton parking identity shown on app chrome, receipts, the WhatsApp
/// action and the contact page. Defaults mirror the backend record before
/// any admin edit (name `Parqueadero`, empty contact fields).
class ParkingSettings extends Equatable {
  const ParkingSettings({
    this.name = 'Parqueadero',
    this.address = '',
    this.schedule = '',
    this.phone = '',
    this.website = '',
    this.whatsapp = '',
    this.logoVersion = 0,
    this.coverPath = '',
    this.coverVersion = 0,
    this.evidenceRetentionDays = 0,
    this.reservationGraceMinutes = 15,
    this.whatsappAuto = false,
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.keyCapacity = 0,
    this.carOutOfService = 0,
    this.motoOutOfService = 0,
    this.legalPolicy = '',
    this.currency = 'COP',
    this.minAppVersion = '',
    this.policePhone = '',
  });

  final String name;
  final String address;
  final String schedule;
  final String phone;
  final String website;
  final String whatsapp;

  /// Server-side counter (`0` = no logo); doubles as the logo cache key.
  final int logoVersion;

  /// Storage path of the wide cover shown on the public page ('' = none).
  final String coverPath;
  final int coverVersion;

  bool get hasCover => coverPath.isNotEmpty;

  /// Evidence photos older than this are deleted by `evidence-archive`.
  /// `0` keeps them forever (default).
  final int evidenceRetentionDays;

  /// Minutes after a hold's expiry where it still counts (and check-in
  /// consumes it). `0` means the hold stops counting exactly on time.
  final int reservationGraceMinutes;

  /// When true, customer messages are queued for the WhatsApp dispatcher
  /// instead of opening `wa.me` on the device.
  final bool whatsappAuto;

  /// Spaces for cars and pickups (shared pool); `0` = no limit. Trucks and
  /// buses are not limited by this setting.
  final int carCapacity;

  /// Spaces for motorcycles; `0` = no limit.
  final int motoCapacity;

  /// How many cars may leave their keys at once; `0` = no limit.
  final int keyCapacity;

  /// Car spots out of the usable pool (maintenance, blocked area).
  final int carOutOfService;

  /// Motorcycle spots out of the usable pool.
  final int motoOutOfService;

  /// Service contract / legal policy shown to customers (editable template).
  final String legalPolicy;

  /// Site currency code (`COP` or `USD`); amounts are minor units of it.
  final String currency;

  /// Oldest app build allowed for this site ('' = no minimum).
  final String minAppVersion;

  /// Nearest police quadrant for the emergency action ('' = use 123).
  final String policePhone;

  /// The never-configured record (mirrors the backend default).
  static ParkingSettings defaults() => const ParkingSettings();

  ParkingSettings copyWith({
    String? name,
    String? address,
    String? schedule,
    String? phone,
    String? website,
    String? whatsapp,
    int? logoVersion,
    String? coverPath,
    int? coverVersion,
    int? evidenceRetentionDays,
    int? reservationGraceMinutes,
    bool? whatsappAuto,
    int? carCapacity,
    int? motoCapacity,
    int? keyCapacity,
    int? carOutOfService,
    int? motoOutOfService,
    String? legalPolicy,
    String? currency,
    String? minAppVersion,
    String? policePhone,
  }) => ParkingSettings(
    name: name ?? this.name,
    address: address ?? this.address,
    schedule: schedule ?? this.schedule,
    phone: phone ?? this.phone,
    website: website ?? this.website,
    whatsapp: whatsapp ?? this.whatsapp,
    logoVersion: logoVersion ?? this.logoVersion,
    coverPath: coverPath ?? this.coverPath,
    coverVersion: coverVersion ?? this.coverVersion,
    evidenceRetentionDays: evidenceRetentionDays ?? this.evidenceRetentionDays,
    reservationGraceMinutes:
        reservationGraceMinutes ?? this.reservationGraceMinutes,
    whatsappAuto: whatsappAuto ?? this.whatsappAuto,
    carCapacity: carCapacity ?? this.carCapacity,
    motoCapacity: motoCapacity ?? this.motoCapacity,
    keyCapacity: keyCapacity ?? this.keyCapacity,
    carOutOfService: carOutOfService ?? this.carOutOfService,
    motoOutOfService: motoOutOfService ?? this.motoOutOfService,
    legalPolicy: legalPolicy ?? this.legalPolicy,
    currency: currency ?? this.currency,
    minAppVersion: minAppVersion ?? this.minAppVersion,
    policePhone: policePhone ?? this.policePhone,
  );

  /// Editable fields (metadata excluded).
  Map<String, dynamic> toPayload() => {
    'name': name,
    'address': address,
    'schedule': schedule,
    'phone': phone,
    'website': website,
    'whatsapp': whatsapp,
    'evidence_retention_days': evidenceRetentionDays,
    'reservation_grace_minutes': reservationGraceMinutes,
    'whatsapp_auto': whatsappAuto,
    'car_capacity': carCapacity,
    'moto_capacity': motoCapacity,
    'key_capacity': keyCapacity,
    'car_out_of_service': carOutOfService,
    'moto_out_of_service': motoOutOfService,
    'legal_policy': legalPolicy,
    'currency': currency,
    'min_app_version': minAppVersion,
    'police_phone': policePhone,
  };

  @override
  List<Object?> get props => [
    name,
    address,
    schedule,
    phone,
    website,
    whatsapp,
    logoVersion,
    coverPath,
    coverVersion,
    evidenceRetentionDays,
    reservationGraceMinutes,
    whatsappAuto,
    carCapacity,
    motoCapacity,
    keyCapacity,
    carOutOfService,
    motoOutOfService,
    legalPolicy,
    currency,
    minAppVersion,
    policePhone,
  ];
}
