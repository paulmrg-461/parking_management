import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/shift_summary.dart';

abstract class ShiftRemoteDataSource {
  Future<ShiftSummary?> current();

  Future<ShiftSummary> open(int openingFloat);

  Future<ShiftSummary> close({required int countedCash, String? notes});

  Future<ShiftSummary> addMovement({
    required String type,
    required int amount,
    required String reason,
  });

  Future<List<ShiftSummary>> history({
    int limit,
    DateTime? from,
    DateTime? to,
  });

  Future<ShiftSummary> adjust({
    required int shiftId,
    required int countedCash,
    required String reason,
  });
}

class SupabaseShiftRemoteDataSource implements ShiftRemoteDataSource {
  SupabaseShiftRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<ShiftSummary?> current() async {
    try {
      final result = await _client.rpc('current_shift');
      return result == null
          ? null
          : ShiftSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ShiftSummary> open(int openingFloat) async {
    try {
      final result = await _client.rpc(
        'open_shift',
        params: {'p_opening_float': openingFloat},
      );
      return ShiftSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ShiftSummary> close({
    required int countedCash,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc(
        'close_shift',
        params: {
          'p_counted_cash': countedCash,
          'p_notes': ?notes,
        },
      );
      return ShiftSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ShiftSummary> addMovement({
    required String type,
    required int amount,
    required String reason,
  }) async {
    try {
      final result = await _client.rpc(
        'add_cash_movement',
        params: {
          'p_type': type,
          'p_amount': amount,
          'p_reason': reason,
        },
      );
      return ShiftSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ShiftSummary> adjust({
    required int shiftId,
    required int countedCash,
    required String reason,
  }) async {
    try {
      final result = await _client.rpc(
        'adjust_shift',
        params: {
          'p_shift_id': shiftId,
          'p_counted_cash': countedCash,
          'p_reason': reason,
        },
      );
      return ShiftSummary.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<ShiftSummary>> history({
    int limit = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final result = await _client.rpc(
        'list_shifts',
        params: {
          'p_limit': limit,
          if (from != null) 'p_start_date': _formatDate(from),
          if (to != null) 'p_end_date': _formatDate(to),
        },
      );
      return [
        for (final item in (result as List<dynamic>))
          ShiftSummary.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
