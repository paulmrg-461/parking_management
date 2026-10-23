import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/vehicle_history.dart';
import '../domain/repositories/vehicle_history_repository.dart';

abstract class VehicleHistoryRemoteDataSource {
  Future<VehicleHistory> lookup(String plate);

  Future<VehicleFlags> updateFlags(
    String plate, {
    bool? blacklisted,
    String? notes,
  });
}

class SupabaseVehicleHistoryRemoteDataSource
    implements VehicleHistoryRemoteDataSource {
  SupabaseVehicleHistoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<VehicleHistory> lookup(String plate) async {
    try {
      final result = await _client.rpc(
        'vehicle_history',
        params: {'p_plate': plate},
      );
      return VehicleHistory.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<VehicleFlags> updateFlags(
    String plate, {
    bool? blacklisted,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc(
        'update_vehicle_flags',
        params: {
          'p_plate': plate,
          'p_blacklisted': ?blacklisted,
          'p_notes': notes,
        },
      );
      return VehicleFlags.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
