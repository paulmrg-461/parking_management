import '../entities/parking_lot.dart';

abstract class LotsRepository {
  /// Lots the signed-in user belongs to (drives the switcher).
  Future<List<ParkingLot>> myLots();

  /// Every lot in the installation (platform admins only).
  Future<List<ParkingLot>> allLots();

  Future<ParkingLot> create({
    required String code,
    required String name,
    String address = '',
    String timezone = 'America/Bogota',
  });

  Future<ParkingLot> update({
    required int id,
    String? name,
    String? address,
    String? timezone,
    bool? active,
  });

  Future<void> setMember({
    required int userId,
    required int lotId,
    required String role,
  });
}
