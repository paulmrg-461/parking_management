import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicle_history/domain/entities/vehicle_history.dart';
import 'package:parking_management/features/vehicle_history/domain/repositories/vehicle_history_repository.dart';

class FakeVehicleHistoryRepository implements VehicleHistoryRepository {
  FakeVehicleHistoryRepository({this.history, this.error});

  VehicleHistory? history;
  Failure? error;
  final List<String> lookups = [];

  @override
  Future<VehicleHistory> lookup(String plate) async {
    lookups.add(plate);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return history!;
  }
}

VehicleHistory sampleHistory({String plate = 'ABC123'}) => VehicleHistory(
  plate: plate,
  vehicleId: 1,
  categoryName: 'car',
  color: 'Rojo',
  brand: 'Mazda',
  visits: 2,
  totalSpent: 12000,
  openSessions: 0,
  sessions: [
    VehicleHistorySession(
      id: 2,
      entryTime: DateTime.utc(2026, 10, 23, 8),
      exitTime: DateTime.utc(2026, 10, 23, 10),
      status: 'closed',
      amountCharged: 7000,
      ticketNumber: 'TCK-000002',
      paymentMethod: 'card',
      durationSeconds: 7200,
    ),
    VehicleHistorySession(
      id: 1,
      entryTime: DateTime.utc(2026, 10, 22, 8),
      exitTime: DateTime.utc(2026, 10, 22, 9),
      status: 'closed',
      amountCharged: 5000,
      ticketNumber: 'TCK-000001',
      paymentMethod: 'cash',
      durationSeconds: 3600,
    ),
  ],
);
