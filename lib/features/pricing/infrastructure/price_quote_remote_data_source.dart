import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/price_quote.dart';
import '../domain/entities/session_price_lock.dart';

abstract class PriceQuoteRemoteDataSource {
  Future<PriceQuote> quote(int categoryId);
  Future<SessionPriceLock?> sessionLock(int sessionId);
  Future<SessionPriceLock?> reservationLock({
    required int lotId,
    required int reservationId,
    required String phone,
  });
}

class SupabasePriceQuoteRemoteDataSource implements PriceQuoteRemoteDataSource {
  SupabasePriceQuoteRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PriceQuote> quote(int categoryId) async {
    try {
      final result = await _client.rpc(
        'pricing_quote',
        params: {'p_category_id': categoryId},
      );
      return PriceQuote.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<SessionPriceLock?> sessionLock(int sessionId) async {
    try {
      final result = await _client.rpc(
        'pricing_session_lock',
        params: {'p_session_id': sessionId},
      );
      if (result is! Map) {
        return null;
      }
      return SessionPriceLock.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<SessionPriceLock?> reservationLock({
    required int lotId,
    required int reservationId,
    required String phone,
  }) async {
    try {
      final result = await _client.rpc(
        'public_reservation_pricing',
        params: {
          'p_lot_id': lotId,
          'p_reservation_id': reservationId,
          'p_customer_phone': phone,
        },
      );
      if (result is! Map) {
        return null;
      }
      return SessionPriceLock.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
