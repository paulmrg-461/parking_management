import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/vehicle_history.dart';

abstract class VehicleHistoryRemoteDataSource {
  Future<VehicleHistory> lookup(String plate);
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
}
