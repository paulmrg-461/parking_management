import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/merchant.dart';
import '../domain/entities/merchant_portal.dart';
import '../domain/entities/merchant_validation_result.dart';

abstract class PublicMerchantRemoteDataSource {
  Future<MerchantPortal?> portal(String token);

  Future<MerchantValidationResult> validate({
    required String token,
    required String pin,
    required String plate,
  });
}

class SupabasePublicMerchantRemoteDataSource
    implements PublicMerchantRemoteDataSource {
  SupabasePublicMerchantRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<MerchantPortal?> portal(String token) async {
    try {
      final result = await _client.rpc(
        'merchant_portal',
        params: {'p_token': token},
      );
      if (result is! Map) {
        return null;
      }
      return MerchantPortal.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MerchantValidationResult> validate({
    required String token,
    required String pin,
    required String plate,
  }) async {
    try {
      final result = await _client.rpc(
        'merchant_validate',
        params: {'p_token': token, 'p_pin': pin, 'p_plate': plate},
      );
      final json = Map<String, dynamic>.from(result as Map);
      return switch (json['status']) {
        'registered' => ValidationRegistered(
          MerchantPortal(
            merchantName: json['merchant_name'] as String? ?? '',
            kind: _kind(json['benefit_kind'] as String?),
            value: (json['benefit_value'] as num?)?.toInt() ?? 0,
            maxAmount: (json['max_amount'] as num?)?.toInt(),
            lotName: '',
          ),
        ),
        'invalid_pin' => ValidationInvalidPin(
          (json['attempts_left'] as num?)?.toInt() ?? 0,
        ),
        _ => ValidationLocked(
          DateTime.tryParse(json['locked_until'] as String? ?? '') ??
              DateTime.now(),
        ),
      };
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static MerchantBenefitKind _kind(String? wire) => switch (wire) {
    'free_minutes' => MerchantBenefitKind.freeMinutes,
    'fixed_amount' => MerchantBenefitKind.fixedAmount,
    _ => MerchantBenefitKind.percentage,
  };
}
