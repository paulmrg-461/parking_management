import '../../check_out/domain/entities/slot_board.dart';
import '../domain/entities/parking_spot.dart';
import '../domain/entities/spot_event.dart';
import '../domain/repositories/spot_repository.dart';
import 'spot_remote_data_source.dart';

class SpotRepositoryImpl implements SpotRepository {
  SpotRepositoryImpl(this._remote);

  final SpotRemoteDataSource _remote;

  @override
  Future<List<ParkingSpot>> list() => _remote.list();

  @override
  Future<ParkingSpot> save({
    int? id,
    required String code,
    required SlotGroup group,
    required int row,
    required int col,
    bool active = true,
    String? reason,
  }) => _remote.save(
    id: id,
    code: code,
    group: group,
    row: row,
    col: col,
    active: active,
    reason: reason,
  );

  @override
  Future<void> delete(int id) => _remote.delete(id);

  @override
  Future<List<SpotEvent>> listEvents(int spotId) => _remote.listEvents(spotId);
}
