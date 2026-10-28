import 'package:equatable/equatable.dart';

/// Public identity and legal policy of a site (no login required).
class LotProfile extends Equatable {
  const LotProfile({
    required this.id,
    required this.name,
    this.address = '',
    this.schedule = '',
    this.phone = '',
    this.website = '',
    this.legalPolicy = '',
  });

  final int id;
  final String name;
  final String address;
  final String schedule;
  final String phone;
  final String website;
  final String legalPolicy;

  factory LotProfile.fromJson(Map<String, dynamic> json) => LotProfile(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    schedule: json['schedule'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    website: json['website'] as String? ?? '',
    legalPolicy: json['legal_policy'] as String? ?? '',
  );

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    schedule,
    phone,
    website,
    legalPolicy,
  ];
}
