import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/pagination/paged_result.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/occupancy_snapshot.dart';
import '../domain/entities/open_session.dart';
import '../domain/entities/today_summary.dart';
import 'models/check_out_receipt_dto.dart';
import 'models/open_session_dto.dart';

abstract class CheckOutRemoteDataSource {
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
    String? plate,
  });

  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
    int? lotId,
  });

  Future<OccupancySnapshot> occupancy();

  Future<TodaySummary> todaySummary();
}

class SupabaseCheckOutRemoteDataSource implements CheckOutRemoteDataSource {
  SupabaseCheckOutRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _view = 'open_sessions_view';

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
    String? plate,
  }) async {
    try {
      var query = _client
          .from(_view)
          .select('id, vehicle_id, entry_time');
      if (plate != null && plate.trim().isNotEmpty) {
        query = query.ilike('plate', '%${plate.trim()}%');
      }
      final response = await query
          .order('entry_time')
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);
      final items = [
        for (final row in response.data)
          OpenSessionDto.fromJson(row).toDomain(),
      ];
      return PagedResult(items, total: response.count);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<OccupancySnapshot> occupancy() async {
    try {
      final result = await _client.rpc('occupancy_snapshot');
      return OccupancySnapshot.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<TodaySummary> todaySummary() async {
    try {
      final result = await _client.rpc('dashboard_today');
      return TodaySummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
    int? lotId,
  }) async {
    try {
      final result = await _client.rpc(
        'check_out',
        params: {
          'p_session_id': sessionId,
          'p_payment_method': paymentMethod,
          if (discountAmount > 0) 'p_discount_amount': discountAmount,
          'p_discount_reason': ?discountReason,
          if (lostTicket) ...{
            'p_lost_ticket': true,
            'p_lost_ticket_reason': ?lostTicketReason,
          },
          if (clientExitTime != null)
            'p_client_exit_time': clientExitTime.toUtc().toIso8601String(),
          'p_idempotency_key': ?idempotencyKey,
          'p_lot_id': ?lotId,
        },
      );
      return CheckOutReceiptDto.fromJson(
        Map<String, dynamic>.from(result as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
