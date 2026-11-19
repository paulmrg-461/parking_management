import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/loyalty_account.dart';
import '../domain/entities/loyalty_report.dart';
import '../domain/entities/loyalty_settings.dart';
import '../domain/entities/loyalty_status.dart';
import '../domain/repositories/loyalty_repository.dart';

abstract class LoyaltyRemoteDataSource {
  Future<LoyaltyStatus> status(String plate);
  Future<LoyaltySettings> loadSettings();
  Future<LoyaltySettings> saveSettings(LoyaltySettings settings);
  Future<void> choose({required int sessionId, required LoyaltyChoice choice});
  Future<List<LoyaltyAccount>> accounts({String? search});
  Future<LoyaltyAdjustResult> adjust({
    required String plate,
    required int delta,
    required String reason,
  });
  Future<LoyaltyReport> report({
    required DateTime start,
    required DateTime end,
  });
}

class SupabaseLoyaltyRemoteDataSource implements LoyaltyRemoteDataSource {
  SupabaseLoyaltyRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<LoyaltyStatus> status(String plate) async {
    try {
      final result = await _client.rpc(
        'loyalty_plate_status',
        params: {'p_plate': plate},
      );
      return LoyaltyStatus.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LoyaltySettings> loadSettings() async {
    try {
      final result = await _client.rpc('get_loyalty_settings');
      return LoyaltySettings.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LoyaltySettings> saveSettings(LoyaltySettings settings) async {
    try {
      final result = await _client.rpc(
        'set_loyalty_settings',
        params: {'p_settings': settings.toJson()},
      );
      return LoyaltySettings.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> choose({
    required int sessionId,
    required LoyaltyChoice choice,
  }) async {
    try {
      await _client.rpc(
        'choose_loyalty_redemption',
        params: {'p_session_id': sessionId, 'p_choice': choice.wire},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<LoyaltyAccount>> accounts({String? search}) async {
    try {
      final result = await _client.rpc(
        'list_loyalty_accounts',
        params: {'p_search': search, 'p_limit': 50},
      );
      return [
        for (final item in (result as List? ?? const []))
          if (item is Map)
            LoyaltyAccount.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LoyaltyAdjustResult> adjust({
    required String plate,
    required int delta,
    required String reason,
  }) async {
    try {
      final result = await _client.rpc(
        'adjust_loyalty_progress',
        params: {'p_plate': plate, 'p_delta': delta, 'p_reason': reason},
      );
      return LoyaltyAdjustResult.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LoyaltyReport> report({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _client.rpc(
        'report_loyalty',
        params: {'p_start_date': _date(start), 'p_end_date': _date(end)},
      );
      return LoyaltyReport.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static String _date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
