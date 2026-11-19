import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/payment_intent.dart';
import '../domain/entities/payment_status.dart';
import 'models/payment_intent_dto.dart';

abstract class OnlinePaymentRemoteDataSource {
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  });

  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  });
}

/// Talks to the `payment-intent` Edge Function (the Wompi keys never reach
/// the client) and to `rpc/payment_intent_status` for the poll.
class SupabaseOnlinePaymentRemoteDataSource
    implements OnlinePaymentRemoteDataSource {
  SupabaseOnlinePaymentRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'payment-intent',
        body: {'session': sessionId, 'plate': plate},
      );
      final data = response.data;
      final json = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      return PaymentIntentDto.fromJson(json).toDomain();
    } on FunctionException catch (error) {
      // The function answers `{"message": "<Name>Error"}` for every refusal
      // (including 429/503): keep the name so the panel can localize it.
      final name = _typedName(error.details);
      if (name != null) {
        throw ValidationFailure(name, name);
      }
      // The functions client wraps a dropped connection as status 0.
      if (error.status == 0) {
        throw const NetworkFailure('Unable to reach the server');
      }
      throw mapSupabaseError(error);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  }) async {
    try {
      final result = await _client.rpc(
        'payment_intent_status',
        params: {'p_reference': reference, 'p_plate': plate},
      );
      if (result is! Map) {
        return null;
      }
      return PaymentIntentStatus.fromJson(
        Map<String, dynamic>.from(result),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static String? _typedName(Object? details) {
    final message = details is Map ? details['message'] : details;
    return message is String && RegExp(r'^[A-Za-z]+Error$').hasMatch(message)
        ? message
        : null;
  }
}
