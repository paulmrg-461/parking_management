import '../entities/vehicle_history.dart';

class VehicleFlags {
  const VehicleFlags({
    required this.plate,
    required this.isBlacklisted,
    this.notes,
  });

  final String plate;
  final bool isBlacklisted;
  final String? notes;

  factory VehicleFlags.fromJson(Map<String, dynamic> json) => VehicleFlags(
    plate: json['plate'] as String,
    isBlacklisted: json['is_blacklisted'] == true,
    notes: json['notes'] as String?,
  );
}

abstract class VehicleHistoryRepository {
  Future<VehicleHistory> lookup(String plate);

  /// Notes are open to any signed-in user; toggling the blacklist is
  /// admin-only (the RPC enforces it).
  Future<VehicleFlags> updateFlags(
    String plate, {
    bool? blacklisted,
    String? notes,
  });
}
