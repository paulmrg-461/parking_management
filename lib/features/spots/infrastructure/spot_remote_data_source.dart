import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../domain/entities/parking_spot.dart';
import '../domain/entities/spot_event.dart';

abstract class SpotRemoteDataSource {
  Future<List<ParkingSpot>> list();

  Future<ParkingSpot> save({
    int? id,
    required String code,
    required SlotGroup group,
    required int row,
    required int col,
    bool active,
    String? reason,
  });

  Future<void> delete(int id);

  Future<List<SpotEvent>> listEvents(int spotId);
}

class SupabaseSpotRemoteDataSource implements SpotRemoteDataSource {
  SupabaseSpotRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'parking_spots';

  @override
  Future<List<ParkingSpot>> list() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('grid_row')
          .order('grid_col');
      return [
        for (final row in rows)
          ParkingSpot.fromJson({
            'id': row['id'],
            'code': row['code'],
            'group': row['group_name'],
            'row': row['grid_row'],
            'col': row['grid_col'],
            'active': row['status'] == 'active',
          }),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingSpot> save({
    int? id,
    required String code,
    required SlotGroup group,
    required int row,
    required int col,
    bool active = true,
    String? reason,
  }) async {
    try {
      final result = await _client.rpc(
        'save_parking_spot',
        params: {
          'p_code': code,
          'p_group': group.name,
          'p_row': row,
          'p_col': col,
          'p_active': active,
          'p_reason': ?reason,
          'p_id': ?id,
        },
      );
      return ParkingSpot.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<SpotEvent>> listEvents(int spotId) async {
    try {
      final result = await _client.rpc(
        'list_spot_events',
        params: {'p_spot_id': spotId},
      );
      return [
        for (final item in result as List)
          SpotEvent.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _client.rpc('delete_parking_spot', params: {'p_id': id});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
