import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/pagination/paged_result.dart';
import '../domain/entities/vehicle.dart';
import 'models/vehicle_dto.dart';

/// PostgREST `or` filter for the registry search: plate, owner name or phone.
/// Values are quoted so spaces or commas in a name do not break the expression.
String? vehicleSearchFilter(String raw) {
  final term = raw.trim();
  if (term.isEmpty) {
    return null;
  }
  final value = '"%${term.replaceAll('"', '')}%"';
  return 'plate.ilike.$value,owner_name.ilike.$value,owner_phone.ilike.$value';
}

abstract class VehicleRemoteDataSource {
  Future<List<Vehicle>> list({String? plate});

  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
    String? query,
  });

  Future<Vehicle> create(Map<String, dynamic> payload);

  Future<Vehicle> update(int id, Map<String, dynamic> payload);

  Future<void> delete(int id);
}

class SupabaseVehicleRemoteDataSource implements VehicleRemoteDataSource {
  SupabaseVehicleRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'vehicles';

  @override
  Future<List<Vehicle>> list({String? plate}) async {
    if (plate != null) {
      try {
        final rows = await _client
            .from(_table)
            .select()
            .eq('plate', plate)
            .order('id');
        return _parse(rows);
      } catch (error) {
        throw mapSupabaseError(error);
      }
    }
    const pageSize = 500;
    final vehicles = <Vehicle>[];
    while (true) {
      final page = await listPage(limit: pageSize, offset: vehicles.length);
      vehicles.addAll(page.items);
      if (page.items.isEmpty || !page.hasMoreAfter(vehicles.length)) {
        return vehicles;
      }
    }
  }

  @override
  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
    String? query,
  }) async {
    try {
      var request = _client.from(_table).select();
      final filter = vehicleSearchFilter(query ?? '');
      if (filter != null) {
        request = request.or(filter);
      }
      final response = await request
          .order('id')
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);
      return PagedResult(_parse(response.data), total: response.count);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  List<Vehicle> _parse(List<Map<String, dynamic>> rows) => [
    for (final row in rows) VehicleDto.fromJson(row).toDomain(),
  ];

  @override
  Future<Vehicle> create(Map<String, dynamic> payload) async {
    try {
      final row = await _client.from(_table).insert(payload).select().single();
      return VehicleDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Vehicle> update(int id, Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return VehicleDto.fromJson(row).toDomain();
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
