import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/public_booking.dart';

abstract class PublicBookingRemoteDataSource {
  Future<PublicBookingAvailability?> availability(int lotId);

  Future<void> cancel({
    required int lotId,
    required int reservationId,
    required String plate,
    required String phone,
  });

  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
  });
}

class SupabasePublicBookingRemoteDataSource
    implements PublicBookingRemoteDataSource {
  SupabasePublicBookingRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PublicBookingAvailability?> availability(int lotId) async {
    try {
      final result = await _client.rpc(
        'public_availability',
        params: {'p_lot_id': lotId},
      );
      if (result is! Map) {
        return null;
      }
      final json = Map<String, dynamic>.from(result);
      final lot = json['lot'] is Map
          ? Map<String, dynamic>.from(json['lot'] as Map)
          : const <String, dynamic>{};
      final logoPath = lot['logo_path'] as String? ?? '';
      final logoUrl = logoPath.isEmpty
          ? null
          : _client.storage.from('branding').getPublicUrl(logoPath);
      return PublicBookingAvailability.fromJson(json, logoUrl: logoUrl);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> cancel({
    required int lotId,
    required int reservationId,
    required String plate,
    required String phone,
  }) async {
    try {
      await _client.rpc(
        'public_cancel_reservation',
        params: {
          'p_lot_id': lotId,
          'p_reservation_id': reservationId,
          'p_plate': plate,
          'p_customer_phone': phone,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
  }) async {
    try {
      final result = await _client.rpc(
        'public_create_reservation',
        params: {
          'p_lot_id': lotId,
          'p_plate': plate,
          'p_category_id': categoryId,
          'p_until': until.toUtc().toIso8601String(),
          'p_customer_name': name,
          'p_customer_phone': phone,
        },
      );
      return PublicReservation.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
