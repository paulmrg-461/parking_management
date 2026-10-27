import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicle_history/domain/entities/vehicle_history.dart';
import 'package:parking_management/features/vehicle_history/domain/repositories/vehicle_history_repository.dart';

class FakeVehicleHistoryRepository implements VehicleHistoryRepository {
  FakeVehicleHistoryRepository({this.history, this.error});

  VehicleHistory? history;
  Failure? error;
  Failure? flagsError;
  final List<String> lookups = [];
  bool? lastBlacklisted;
  String? lastNotes;
  String? lastOwnerPhone;

  @override
  Future<VehicleHistory> lookup(String plate) async {
    lookups.add(plate);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return history!;
  }

  @override
  Future<VehicleFlags> updateFlags(
    String plate, {
    bool? blacklisted,
    String? notes,
    String? ownerPhone,
  }) async {
    final error = flagsError;
    if (error != null) {
      throw error;
    }
    lastBlacklisted = blacklisted;
    lastNotes = notes;
    lastOwnerPhone = ownerPhone;
    final current = history;
    final next = current?.withFlags(
      isBlacklisted: blacklisted,
      notes: notes,
      replaceNotes: true,
      ownerPhone: ownerPhone,
      replaceOwnerPhone: true,
    );
    history = next;
    return VehicleFlags(
      plate: plate,
      isBlacklisted: next?.isBlacklisted ?? false,
      notes: next?.notes,
      ownerPhone: next?.ownerPhone,
    );
  }
}

VehicleHistory sampleHistory({
  String plate = 'ABC123',
  String? ownerPhone,
  bool withOpenSession = false,
}) => VehicleHistory(
  plate: plate,
  vehicleId: 1,
  categoryName: 'car',
  color: 'Rojo',
  brand: 'Mazda',
  visits: 2,
  totalSpent: 12000,
  openSessions: 0,
  currentLotVisits: 1,
  ownerPhone: ownerPhone,
  sessions: [
    if (withOpenSession)
      VehicleHistorySession(
        id: 3,
        entryTime: DateTime.utc(2026, 10, 24, 8),
        status: 'open',
        durationSeconds: 3600,
        lotId: 1,
        lotName: 'Central',
      ),
    VehicleHistorySession(
      id: 2,
      entryTime: DateTime.utc(2026, 10, 23, 8),
      exitTime: DateTime.utc(2026, 10, 23, 10),
      status: 'closed',
      amountCharged: 7000,
      ticketNumber: 'TCK-000002',
      paymentMethod: 'card',
      durationSeconds: 7200,
      lotId: 1,
      lotName: 'Central',
      discountAmount: 1000,
      discountReason: 'cortesia',
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
      lotId: 2,
      lotName: 'North',
    ),
  ],
);
