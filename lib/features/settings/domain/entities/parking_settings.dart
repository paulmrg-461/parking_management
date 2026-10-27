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
    this.evidenceRetentionDays = 0,
    this.whatsappAuto = false,
    this.carCapacity = 0,
    this.motoCapacity = 0,
    this.keyCapacity = 0,
  });

  final String name;
  final String address;
  final String schedule;
  final String phone;
  final String website;
  final String whatsapp;

  /// Server-side counter (`0` = no logo); doubles as the logo cache key.
  final int logoVersion;

  /// Evidence photos older than this are deleted by `evidence-archive`.
  /// `0` keeps them forever (default).
  final int evidenceRetentionDays;

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
    int? evidenceRetentionDays,
    bool? whatsappAuto,
    int? carCapacity,
    int? motoCapacity,
    int? keyCapacity,
  }) => ParkingSettings(
    name: name ?? this.name,
    address: address ?? this.address,
    schedule: schedule ?? this.schedule,
    phone: phone ?? this.phone,
    website: website ?? this.website,
    whatsapp: whatsapp ?? this.whatsapp,
    logoVersion: logoVersion ?? this.logoVersion,
    evidenceRetentionDays:
        evidenceRetentionDays ?? this.evidenceRetentionDays,
    whatsappAuto: whatsappAuto ?? this.whatsappAuto,
    carCapacity: carCapacity ?? this.carCapacity,
    motoCapacity: motoCapacity ?? this.motoCapacity,
    keyCapacity: keyCapacity ?? this.keyCapacity,
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
    'whatsapp_auto': whatsappAuto,
    'car_capacity': carCapacity,
    'moto_capacity': motoCapacity,
    'key_capacity': keyCapacity,
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
    evidenceRetentionDays,
    whatsappAuto,
    carCapacity,
    motoCapacity,
    keyCapacity,
  ];
}
