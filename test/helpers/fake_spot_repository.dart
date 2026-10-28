import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/domain/repositories/spot_repository.dart';

class FakeSpotRepository implements SpotRepository {
  FakeSpotRepository([List<ParkingSpot> spots = const []])
    : spots = List.of(spots);

  List<ParkingSpot> spots;
  Failure? listError;
  Failure? writeError;
  int nextId = 100;
  int listCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<ParkingSpot>> list() async {
    listCalls++;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return List.of(spots);
  }

  @override
  Future<ParkingSpot> save({
    int? id,
    required String code,
    required SlotGroup group,
    required int row,
    required int col,
    bool active = true,
  }) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    final spot = ParkingSpot(
      id: id ?? nextId++,
      code: code,
      group: group,
      row: row,
      col: col,
      active: active,
    );
    final exists = spots.any((item) => item.id == spot.id);
    spots = [
      for (final item in spots)
        if (item.id == spot.id) spot else item,
      if (!exists) spot,
    ];
    return spot;
  }

  @override
  Future<void> delete(int id) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    deleteCalls++;
    spots = [
      for (final item in spots)
        if (item.id != id) item,
    ];
  }
}
