import 'package:equatable/equatable.dart';

/// Space configuration vs. what is inside (cars + pickups, motorcycles and
/// cars that left their keys). A capacity of `0` means "no limit".
class CapacitySnapshot extends Equatable {
  const CapacitySnapshot({
    this.carOpen = 0,
    this.carCapacity = 0,
    this.carReserved = 0,
    this.motoOpen = 0,
    this.motoCapacity = 0,
    this.motoReserved = 0,
    this.keysOpen = 0,
    this.keyCapacity = 0,
    this.reservationsActive = 0,
    this.reservationsExpiring = 0,
  });

  final int carOpen;
  final int carCapacity;

  /// Active holds for the car group (spots promised, not occupied yet).
  final int carReserved;
  final int motoOpen;
  final int motoCapacity;
  final int motoReserved;
  final int keysOpen;
  final int keyCapacity;

  /// Active holds for the site, and those ending within two hours.
  final int reservationsActive;
  final int reservationsExpiring;

  static const empty = CapacitySnapshot();

  bool get carsFull => carCapacity > 0 && carOpen >= carCapacity;
  bool get motosFull => motoCapacity > 0 && motoOpen >= motoCapacity;
  bool get keysFull => keyCapacity > 0 && keysOpen >= keyCapacity;

  factory CapacitySnapshot.fromJson(Map<String, dynamic> json) =>
      CapacitySnapshot(
        carOpen: (json['car_open'] as num?)?.toInt() ?? 0,
        carCapacity: (json['car_capacity'] as num?)?.toInt() ?? 0,
        carReserved: (json['car_reserved'] as num?)?.toInt() ?? 0,
        motoOpen: (json['moto_open'] as num?)?.toInt() ?? 0,
        motoCapacity: (json['moto_capacity'] as num?)?.toInt() ?? 0,
        motoReserved: (json['moto_reserved'] as num?)?.toInt() ?? 0,
        keysOpen: (json['keys_open'] as num?)?.toInt() ?? 0,
        keyCapacity: (json['key_capacity'] as num?)?.toInt() ?? 0,
        reservationsActive:
            (json['reservations_active'] as num?)?.toInt() ?? 0,
        reservationsExpiring:
            (json['reservations_expiring'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
    carOpen,
    carCapacity,
    carReserved,
    motoOpen,
    motoCapacity,
    motoReserved,
    keysOpen,
    keyCapacity,
    reservationsActive,
    reservationsExpiring,
  ];
}
