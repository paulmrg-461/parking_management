import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_offer.dart';
import 'package:parking_management/features/pass_renewal/infrastructure/pass_renewal_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _offer = {
  'status': 'open',
  'lot_name': 'Central',
  'plate_masked': 'ABC***',
  'period_start': '2026-12-01',
  'period_end': '2026-12-31',
  'amount': 80000,
  'currency': 'COP',
  'expires_at': '2026-11-30T12:00:00.000Z',
  'payment_links_enabled': true,
};

const _checkout = {
  'intent_id': 12,
  'reference': 'PM-1A2B3C4D5E6F',
  'amount': 80000,
  'currency': 'COP',
  'checkout_url': 'https://checkout.wompi.co/p/?reference=PM-1A2B3C4D5E6F',
  'expires_at': '2026-11-17T12:30:00.000Z',
};

({SupabasePassRenewalRemoteDataSource remote, List<http.Request> sent})
_harness({
  int functionStatus = 200,
  Object? functionBody,
  Object? rpcBody,
  bool networkError = false,
}) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      if (networkError) {
        throw http.ClientException('offline', request.url);
      }
      if (request.url.path.contains('/functions/v1/pass-renewal-intent')) {
        return http.Response(
          jsonEncode(functionBody ?? _checkout),
          functionStatus,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        jsonEncode(rpcBody),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (remote: SupabasePassRenewalRemoteDataSource(client), sent: sent);
}

void main() {
  test('Success: load maps the offer', () async {
    final harness = _harness(rpcBody: _offer);
    final offer = await harness.remote.load('a' * 48);

    expect(offer, isNotNull);
    expect(offer!.status, PassRenewalStatus.open);
    expect(offer.plateMasked, 'ABC***');
    expect(offer.amount, 80000);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_token'], 'a' * 48);
  });

  test('Success: an unknown token returns null', () async {
    final harness = _harness(rpcBody: null);
    expect(await harness.remote.load('a' * 48), isNull);
  });

  test('Success: startPayment maps checkout_url', () async {
    final harness = _harness();
    final checkout = await harness.remote.startPayment('a' * 48);

    expect(checkout.checkoutUrl, contains('checkout.wompi.co'));
    expect(checkout.reference, 'PM-1A2B3C4D5E6F');
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['token'], 'a' * 48);
  });

  test('Failure: a typed refusal keeps its code', () {
    final harness = _harness(
      functionStatus: 409,
      functionBody: {'message': 'PassRenewalPaidError'},
    );
    expect(
      () => harness.remote.startPayment('a' * 48),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'PassRenewalPaidError',
        ),
      ),
    );
  });

  test('Failure: a network drop becomes NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(
      () => harness.remote.load('a' * 48),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
