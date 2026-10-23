import '../domain/entities/parking_lot.dart';
import '../domain/repositories/lots_repository.dart';
import 'lots_remote_data_source.dart';

class LotsRepositoryImpl implements LotsRepository {
  LotsRepositoryImpl(this._remote);

  final LotsRemoteDataSource _remote;

  @override
  Future<List<ParkingLot>> myLots() => _remote.myLots();

  @override
  Future<List<ParkingLot>> allLots() => _remote.allLots();

  @override
  Future<ParkingLot> create({
    required String code,
    required String name,
    String address = '',
    String timezone = 'America/Bogota',
  }) => _remote.create(
    code: code,
    name: name,
    address: address,
    timezone: timezone,
  );

  @override
  Future<ParkingLot> update({
    required int id,
    String? name,
    String? address,
    String? timezone,
    bool? active,
  }) => _remote.update(
    id: id,
    name: name,
    address: address,
    timezone: timezone,
    active: active,
  );

  @override
  Future<void> setMember({
    required int userId,
    required int lotId,
    required String role,
  }) => _remote.setMember(userId: userId, lotId: lotId, role: role);
}
