import 'package:equatable/equatable.dart';

class ParkingLot extends Equatable {
  const ParkingLot({
    required this.id,
    required this.code,
    required this.name,
    this.timezone = 'America/Bogota',
    this.role = 'operator',
    this.active = true,
    this.address = '',
    this.members = 0,
  });

  final int id;
  final String code;
  final String name;
  final String timezone;

  /// The signed-in user's role in this lot (`operator` or `admin`).
  final String role;
  final bool active;
  final String address;
  final int members;

  bool get isLotAdmin => role == 'admin';

  factory ParkingLot.fromJson(Map<String, dynamic> json) => ParkingLot(
    id: (json['id'] as num).toInt(),
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    timezone: json['timezone'] as String? ?? 'America/Bogota',
    role: json['role'] as String? ?? 'operator',
    active: json['active'] as bool? ?? true,
    address: json['address'] as String? ?? '',
    members: (json['members'] as num?)?.toInt() ?? 0,
  );

  ParkingLot copyWith({
    String? name,
    String? address,
    bool? active,
    String? role,
  }) => ParkingLot(
    id: id,
    code: code,
    name: name ?? this.name,
    timezone: timezone,
    role: role ?? this.role,
    active: active ?? this.active,
    address: address ?? this.address,
    members: members,
  );

  @override
  List<Object?> get props => [id, code, name, timezone, role, active, address];
}
