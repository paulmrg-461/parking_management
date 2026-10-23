import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/monthly_pass.dart';
import 'models/monthly_pass_dto.dart';

abstract class MonthlyPassRemoteDataSource {
  Future<List<MonthlyPass>> list({int? vehicleId});

  Future<MonthlyPass> create(Map<String, dynamic> payload);

  Future<MonthlyPass> update(int id, Map<String, dynamic> payload);

  Future<void> delete(int id);
}

class SupabaseMonthlyPassRemoteDataSource implements MonthlyPassRemoteDataSource {
  SupabaseMonthlyPassRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'monthly_passes';

  @override
  Future<List<MonthlyPass>> list({int? vehicleId}) async {
    try {
      var query = _client.from(_table).select();
      if (vehicleId != null) {
        query = query.eq('vehicle_id', vehicleId);
      }
      final rows = await query.order('id');
      return rows
          .map((row) => MonthlyPassDto.fromJson(row).toDomain())
          .toList();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MonthlyPass> create(Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .insert(payload)
          .select()
          .single();
      return MonthlyPassDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MonthlyPass> update(int id, Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return MonthlyPassDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
