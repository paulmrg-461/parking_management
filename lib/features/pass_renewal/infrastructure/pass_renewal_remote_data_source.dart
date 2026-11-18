import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/pass_renewal_checkout.dart';
import '../domain/entities/pass_renewal_offer.dart';

abstract class PassRenewalRemoteDataSource {
  Future<PassRenewalOffer?> load(String token);

  Future<PassRenewalCheckout> startPayment(String token);
}

/// Public RPC for the offer and the `pass-renewal-intent` Edge Function for
/// the checkout (the gateway keys never reach the client).
class SupabasePassRenewalRemoteDataSource
    implements PassRenewalRemoteDataSource {
  SupabasePassRenewalRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PassRenewalOffer?> load(String token) async {
    try {
      final result = await _client.rpc(
        'public_pass_renewal',
        params: {'p_token': token},
      );
      if (result is! Map) {
        return null;
      }
      return PassRenewalOffer.fromJson(
        Map<String, dynamic>.from(result),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PassRenewalCheckout> startPayment(String token) async {
    try {
      final response = await _client.functions.invoke(
        'pass-renewal-intent',
        body: {'token': token},
      );
      final data = response.data;
      final json = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      return PassRenewalCheckout.fromJson(json);
    } on FunctionException catch (error) {
      final name = _typedName(error.details);
      if (name != null) {
        throw ValidationFailure(name, name);
      }
      if (error.status == 0) {
        throw const NetworkFailure('Unable to reach the server');
      }
      throw mapSupabaseError(error);
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
