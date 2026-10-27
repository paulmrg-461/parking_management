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

class SupabaseReservationRemoteDataSource implements ReservationRemoteDataSource {
  SupabaseReservationRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'category_reservations';

  @override
  Future<List<Reservation>> listActive() async {
    try {
      final rows = await _client
          .from(_table)
          .select(
            'id, plate, category_id, reserved_until, status, notes, '
            'categories(name)',
          )
          .eq('status', 'active')
          .gt('reserved_until', DateTime.now().toUtc().toIso8601String())
          .order('reserved_until');
      return [
        for (final row in rows) Reservation.fromJson(row),
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
