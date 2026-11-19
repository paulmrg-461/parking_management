import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/reservation.dart';

abstract class ReservationRemoteDataSource {
  Future<List<Reservation>> listActive();

  Future<Reservation> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  });

  Future<void> cancel(int id);
}

class SupabaseReservationRemoteDataSource
    implements ReservationRemoteDataSource {
  SupabaseReservationRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Reservation>> listActive() async {
    try {
      // The RPC applies `reservation_grace()` and returns `in_grace`, so the
      // app never re-implements the window (see 0097).
      final rows = await _client.rpc('list_active_reservations');
      return [
        for (final row in rows as List<dynamic>)
          Reservation.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Reservation> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc(
        'create_reservation',
        params: {
          'p_plate': plate,
          'p_category_id': categoryId,
          'p_until': until.toUtc().toIso8601String(),
          'p_notes': ?notes,
        },
      );
      return Reservation.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _client.rpc('cancel_reservation', params: {'p_id': id});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
