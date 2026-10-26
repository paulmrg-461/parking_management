import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/lot_member.dart';
import '../domain/entities/parking_lot.dart';

abstract class LotsRemoteDataSource {
  Future<List<ParkingLot>> myLots();

  Future<List<ParkingLot>> allLots();

  Future<ParkingLot> create({
    required String code,
    required String name,
    required String address,
    required String timezone,
  });

  Future<ParkingLot> update({
    required int id,
    String? name,
    String? address,
    String? timezone,
    bool? active,
  });

  Future<List<LotMember>> members(int lotId);

  Future<void> setMember({
    required int userId,
    required int lotId,
    required String role,
  });
}

class SupabaseLotsRemoteDataSource implements LotsRemoteDataSource {
  SupabaseLotsRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ParkingLot>> myLots() async {
    try {
      final result = await _client.rpc('my_lots');
      return _list(result);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<ParkingLot>> allLots() async {
    try {
      final result = await _client.rpc('list_lots');
      return _list(result);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingLot> create({
    required String code,
    required String name,
    required String address,
    required String timezone,
  }) async {
    try {
      final result = await _client.rpc(
        'create_lot',
        params: {
          'p_code': code,
          'p_name': name,
          'p_address': address,
          'p_timezone': timezone,
        },
      );
      return ParkingLot.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingLot> update({
    required int id,
    String? name,
    String? address,
    String? timezone,
    bool? active,
  }) async {
    try {
      final result = await _client.rpc(
        'update_lot',
        params: {
          'p_id': id,
          'p_name': ?name,
          'p_address': ?address,
          'p_timezone': ?timezone,
          'p_active': ?active,
        },
      );
      return ParkingLot.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<LotMember>> members(int lotId) async {
    try {
      final result = await _client.rpc(
        'list_lot_members',
        params: {'p_lot_id': lotId},
      );
      return [
        for (final item in (result as List<dynamic>? ?? const []))
          LotMember.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> setMember({
    required int userId,
    required int lotId,
    required String role,
  }) async {
    try {
      await _client.rpc(
        'set_lot_member',
        params: {
          'p_user_id': userId,
          'p_lot_id': lotId,
          'p_role': role,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  List<ParkingLot> _list(Object? result) => [
    for (final item in (result as List<dynamic>? ?? const []))
      ParkingLot.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}
