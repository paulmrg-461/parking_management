import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/public_waitlist.dart';

/// The anonymous waitlist RPCs, plus the `public-booking` Edge Function when a
/// captcha token is present (the lot requires one).
abstract class PublicWaitlistRemoteDataSource {
  Future<PublicWaitlistInfo?> info(int lotId);

  Future<PublicWaitlistEntry> join({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime waitUntil,
    required int holdMinutes,
    required String phone,
    required String name,
    String? captchaToken,
  });

  Future<PublicWaitlistEntry?> lookup({
    required int lotId,
    required int entryId,
    required String phone,
  });

  Future<PublicReservation> claim({
    required int lotId,
    required int entryId,
    required String phone,
  });

  Future<void> leave({
    required int lotId,
    required int entryId,
    required String phone,
  });
}

class SupabasePublicWaitlistRemoteDataSource
    implements PublicWaitlistRemoteDataSource {
  SupabasePublicWaitlistRemoteDataSource(this._client);

  final SupabaseClient _client;

  static final _typedError = RegExp(
    r'^(Waitlist|Offer|Booking|Captcha|Invalid|Category|Lot|Reservation|'
    r'Vehicle|Admin)[A-Za-z]*Error$',
  );

  @override
  Future<PublicWaitlistInfo?> info(int lotId) async {
    try {
      final result = await _client.rpc(
        'public_waitlist_info',
        params: {'p_lot_id': lotId},
      );
      if (result is! Map) {
        return null;
      }
      return PublicWaitlistInfo.fromJson(
        Map<String, dynamic>.from(result),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PublicWaitlistEntry> join({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime waitUntil,
    required int holdMinutes,
    required String phone,
    required String name,
    String? captchaToken,
  }) async {
    try {
      final Object? result;
      if (captchaToken != null && captchaToken.isNotEmpty) {
        result = await _verifiedJoin({
          'action': 'waitlist_join',
          'lot_id': lotId,
          'plate': plate,
          'category_id': categoryId,
          'wait_until': waitUntil.toUtc().toIso8601String(),
          'hold_minutes': holdMinutes,
          'name': name,
          'phone': phone,
          'captcha_token': captchaToken,
        });
      } else {
        result = await _client.rpc(
          'public_join_waitlist',
          params: {
            'p_lot_id': lotId,
            'p_plate': plate,
            'p_category_id': categoryId,
            'p_wait_until': waitUntil.toUtc().toIso8601String(),
            'p_hold_minutes': holdMinutes,
            'p_customer_name': name,
            'p_customer_phone': phone,
          },
        );
      }
      return PublicWaitlistEntry.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on Failure {
      rethrow;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Object?> _verifiedJoin(Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke(
        'public-booking',
        body: body,
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['message'] : null;
      if (message is String && _typedError.hasMatch(message)) {
        throw ValidationFailure(message, message);
      }
      rethrow;
    }
  }

  @override
  Future<PublicWaitlistEntry?> lookup({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    try {
      final result = await _client.rpc(
        'public_waitlist_lookup',
        params: {
          'p_lot_id': lotId,
          'p_entry_id': entryId,
          'p_customer_phone': phone,
        },
      );
      if (result is! Map) {
        return null;
      }
      return PublicWaitlistEntry.fromJson(
        Map<String, dynamic>.from(result),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PublicReservation> claim({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    try {
      final result = await _client.rpc(
        'public_claim_waitlist',
        params: {
          'p_lot_id': lotId,
          'p_entry_id': entryId,
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

  @override
  Future<void> leave({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    try {
      await _client.rpc(
        'public_leave_waitlist',
        params: {
          'p_lot_id': lotId,
          'p_entry_id': entryId,
          'p_customer_phone': phone,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
