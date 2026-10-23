import '../entities/vehicle_history.dart';

abstract class VehicleHistoryRepository {
  Future<VehicleHistory> lookup(String plate);
}
