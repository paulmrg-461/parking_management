import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/waitlist_entry.dart';
import '../domain/entities/waitlist_settings.dart';

/// Desk RPCs and the settings row of the active lot.
abstract class WaitlistRemoteDataSource {
  Future<List<WaitlistEntry>> list();

  Future<PublicReservation> claim(int id);

  Future<void> remove(int id);

  Future<WaitlistSettings> loadSettings();

  Future<WaitlistSettings> saveSettings(WaitlistSettings settings);
}

class SupabaseWaitlistRemoteDataSource implements WaitlistRemoteDataSource {
  SupabaseWaitlistRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'parking_settings';

  @override
  Future<List<WaitlistEntry>> list() async {
    try {
      final rows = await _client.rpc('list_waitlist');
      return (rows as List)
          .map(
            (row) =>
                WaitlistEntry.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PublicReservation> claim(int id) async {
    try {
      final result = await _client.rpc(
        'desk_claim_waitlist',
        params: {'p_id': id},
      );
      return PublicReservation.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> remove(int id) async {
    try {
      await _client.rpc('desk_remove_waitlist', params: {'p_id': id});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<WaitlistSettings> loadSettings() async {
    try {
      final rows = await _client
          .from(_table)
          .select(
            'waitlist_enabled,waitlist_claim_minutes,waitlist_max_entries',
          )
          .limit(1);
      if (rows.isEmpty) {
        return WaitlistSettings.defaults;
      }
      return WaitlistSettings.fromJson(
        Map<String, dynamic>.from(rows.first),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<WaitlistSettings> saveSettings(WaitlistSettings settings) async {
    try {
      final result = await _client.rpc(
        'set_waitlist_settings',
        params: {
          'p_enabled': settings.enabled,
          'p_claim_minutes': settings.claimMinutes,
          'p_max_entries': settings.maxEntries,
        },
      );
      return WaitlistSettings.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
