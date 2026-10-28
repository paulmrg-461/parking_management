import '../../../check_out/domain/entities/slot_board.dart';
import '../entities/parking_spot.dart';

/// Physical map of the site. Writes are admin-only on the server.
abstract class SpotRepository {
  Future<List<ParkingSpot>> list();

  Future<ParkingSpot> save({
    int? id,
    required String code,
    required SlotGroup group,
    required int row,
    required int col,
    bool active = true,
  });

  Future<void> delete(int id);
}
