import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/fare/fare_quote.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/merchant.dart';
import '../domain/entities/merchant_settlement.dart';

abstract class MerchantRemoteDataSource {
  Future<List<Merchant>> list();

  Future<List<Merchant>> listActive();

  Future<({Merchant merchant, MerchantCredentials? credentials})> save(
    MerchantDraft draft,
  );

  Future<MerchantCredentials> resetCredentials(
    int merchantId, {
    bool rotateToken,
  });

  Future<void> delete(int merchantId);

  Future<int> loadPolicy();

  Future<int> savePolicy(int maxPerSession);

  Future<FareQuote> addValidation({
    required int merchantId,
    required int sessionId,
  });

  Future<void> revokeValidation({
    required int validationId,
    required String reason,
  });

  Future<MerchantSettlement> settlement({
    required DateTime start,
    required DateTime end,
  });
}

class SupabaseMerchantRemoteDataSource implements MerchantRemoteDataSource {
  SupabaseMerchantRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Merchant>> list() async {
    try {
      final result = await _client.rpc('list_merchants');
      return [
        for (final item in (result as List? ?? const []))
          if (item is Map) Merchant.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<Merchant>> listActive() async {
    try {
      final result = await _client.rpc('list_active_merchants');
      return [
        for (final item in (result as List? ?? const []))
          if (item is Map) Merchant.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<({Merchant merchant, MerchantCredentials? credentials})> save(
    MerchantDraft draft,
  ) async {
    try {
      final result = await _client.rpc(
        'save_merchant',
        params: {
          'p_name': draft.name,
          'p_benefit_kind': draft.kind.wire,
          'p_benefit_value': draft.value,
          'p_max_amount': draft.maxAmount,
          'p_billing_mode': draft.billingMode.wire,
          'p_daily_cap': draft.dailyCap,
          'p_monthly_cap': draft.monthlyCap,
          'p_active': draft.active,
          'p_id': draft.id,
        },
      );
      final json = Map<String, dynamic>.from(result as Map);
      final merchant = Merchant.fromJson(
        Map<String, dynamic>.from(json['merchant'] as Map),
      );
      final raw = json['credentials'];
      MerchantCredentials? credentials;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        credentials = MerchantCredentials(
          merchantId: merchant.id,
          pin: data['pin'] as String? ?? '',
          token: data['token'] as String?,
          linkPath: data['link_path'] as String?,
        );
      }
      return (merchant: merchant, credentials: credentials);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MerchantCredentials> resetCredentials(
    int merchantId, {
    bool rotateToken = false,
  }) async {
    try {
      final result = await _client.rpc(
        'reset_merchant_credentials',
        params: {
          'p_merchant_id': merchantId,
          'p_rotate_token': rotateToken,
        },
      );
      final json = Map<String, dynamic>.from(result as Map);
      return MerchantCredentials(
        merchantId: (json['merchant_id'] as num?)?.toInt() ?? merchantId,
        pin: json['pin'] as String? ?? '',
        token: json['token'] as String?,
        linkPath: json['link_path'] as String?,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int merchantId) async {
    try {
      await _client.rpc('delete_merchant', params: {'p_id': merchantId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<int> loadPolicy() async {
    try {
      final rows = await _client
          .from('parking_settings')
          .select('merchant_max_per_session')
          .limit(1);
      if (rows.isEmpty) {
        return 1;
      }
      return (rows.first['merchant_max_per_session'] as num?)?.toInt() ?? 1;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<int> savePolicy(int maxPerSession) async {
    try {
      final result = await _client.rpc(
        'set_merchant_policy',
        params: {'p_max_per_session': maxPerSession},
      );
      final json = Map<String, dynamic>.from(result as Map);
      return (json['max_per_session'] as num?)?.toInt() ?? maxPerSession;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<FareQuote> addValidation({
    required int merchantId,
    required int sessionId,
  }) async {
    try {
      final result = await _client.rpc(
        'add_merchant_validation',
        params: {
          'p_merchant_id': merchantId,
          'p_session_id': sessionId,
        },
      );
      final json = Map<String, dynamic>.from(result as Map);
      return FareQuote.fromJson(
        Map<String, dynamic>.from(json['quote'] as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> revokeValidation({
    required int validationId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'revoke_merchant_validation',
        params: {'p_id': validationId, 'p_reason': reason},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<MerchantSettlement> settlement({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _client.rpc(
        'report_merchant_settlement',
        params: {
          'p_start_date': _date(start),
          'p_end_date': _date(end),
        },
      );
      return MerchantSettlement.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
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
