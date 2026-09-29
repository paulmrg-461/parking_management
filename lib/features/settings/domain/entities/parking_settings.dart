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
  });

  final String name;
  final String address;
  final String schedule;
  final String phone;
  final String website;
  final String whatsapp;

  /// Server-side counter (`0` = no logo); doubles as the logo cache key.
  final int logoVersion;

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
  }) => ParkingSettings(
    name: name ?? this.name,
    address: address ?? this.address,
    schedule: schedule ?? this.schedule,
    phone: phone ?? this.phone,
    website: website ?? this.website,
    whatsapp: whatsapp ?? this.whatsapp,
    logoVersion: logoVersion ?? this.logoVersion,
  );

  /// Fields accepted by `PATCH /api/settings` (metadata excluded).
  Map<String, dynamic> toPayload() => {
    'name': name,
    'address': address,
    'schedule': schedule,
    'phone': phone,
    'website': website,
    'whatsapp': whatsapp,
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
  ];
}
