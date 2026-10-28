import 'package:equatable/equatable.dart';

/// Space configuration vs. what is inside (cars + pickups, motorcycles and
/// cars that left their keys). A capacity of `0` means "no limit".
class CapacitySnapshot extends Equatable {
  const CapacitySnapshot({
    this.carOpen = 0,
    this.carCapacity = 0,
    this.carOutOfService = 0,
    this.carReserved = 0,
    this.motoOpen = 0,
    this.motoCapacity = 0,
    this.motoOutOfService = 0,
    this.motoReserved = 0,
    this.keysOpen = 0,
    this.keyCapacity = 0,
    this.reservationsActive = 0,
    this.reservationsExpiring = 0,
  });

  final int carOpen;
  final int carCapacity;

  /// Car spots out of the usable pool (maintenance, blocked area).
  final int carOutOfService;

  /// Active holds for the car group (spots promised, not occupied yet).
  final int carReserved;
  final int motoOpen;
  final int motoCapacity;
  final int motoOutOfService;
  final int motoReserved;
  final int keysOpen;
  final int keyCapacity;

  /// Active holds for the site, and those ending within two hours.
  final int reservationsActive;
  final int reservationsExpiring;

  static const empty = CapacitySnapshot();

  /// Usable car spots: configured capacity minus the ones out of service.
  /// `0` capacity means "no limit", so this stays `0` too.
  int get carAvailable => carCapacity <= 0
      ? 0
      : (carCapacity - carOutOfService).clamp(0, carCapacity);

  /// Usable motorcycle spots (see [carAvailable]).
  int get motoAvailable => motoCapacity <= 0
      ? 0
      : (motoCapacity - motoOutOfService).clamp(0, motoCapacity);

  /// Free car spots: usable minus what is inside and what is held.
  int get carFree => carCapacity <= 0
      ? 0
      : (carAvailable - carOpen - carReserved).clamp(0, carAvailable);

  /// Free motorcycle spots: usable minus what is inside and what is held.
  int get motoFree => motoCapacity <= 0
      ? 0
      : (motoAvailable - motoOpen - motoReserved).clamp(0, motoAvailable);

  bool get carsFull => carCapacity > 0 && carOpen + carReserved >= carAvailable;
  bool get motosFull =>
      motoCapacity > 0 && motoOpen + motoReserved >= motoAvailable;
  bool get keysFull => keyCapacity > 0 && keysOpen >= keyCapacity;

  factory CapacitySnapshot.fromJson(Map<String, dynamic> json) =>
      CapacitySnapshot(
        carOpen: (json['car_open'] as num?)?.toInt() ?? 0,
        carCapacity: (json['car_capacity'] as num?)?.toInt() ?? 0,
        carOutOfService: (json['car_out_of_service'] as num?)?.toInt() ?? 0,
        carReserved: (json['car_reserved'] as num?)?.toInt() ?? 0,
        motoOpen: (json['moto_open'] as num?)?.toInt() ?? 0,
        motoCapacity: (json['moto_capacity'] as num?)?.toInt() ?? 0,
        motoOutOfService: (json['moto_out_of_service'] as num?)?.toInt() ?? 0,
        motoReserved: (json['moto_reserved'] as num?)?.toInt() ?? 0,
        keysOpen: (json['keys_open'] as num?)?.toInt() ?? 0,
        keyCapacity: (json['key_capacity'] as num?)?.toInt() ?? 0,
        reservationsActive: (json['reservations_active'] as num?)?.toInt() ?? 0,
        reservationsExpiring:
            (json['reservations_expiring'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [
    carOpen,
    carCapacity,
    carOutOfService,
    carReserved,
    motoOpen,
    motoCapacity,
    motoOutOfService,
    motoReserved,
    keysOpen,
    keyCapacity,
    reservationsActive,
    reservationsExpiring,
  ];
}
