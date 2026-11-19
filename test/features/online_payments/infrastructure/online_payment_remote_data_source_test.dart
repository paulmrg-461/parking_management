import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_status.dart';
import 'package:parking_management/features/online_payments/infrastructure/online_payment_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _intent = {
  'intent_id': 9,
  'reference': 'PM-1A2B3C4D5E6F',
  'amount': 6000,
  'currency': 'COP',
  'checkout_url': 'https://checkout.wompi.co/p/?reference=PM-1A2B3C4D5E6F',
  'expires_at': '2026-11-17T12:30:00.000Z',
  'grace_minutes': 15,
};

const _status = {
  'status': 'approved',
  'amount': 6000,
  'session_id': 55,
  'paid_total': 6000,
  'grace_until': '2026-11-17T13:00:00.000Z',
};

({SupabaseOnlinePaymentRemoteDataSource remote, List<http.Request> sent})
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
      if (request.url.path.contains('/functions/v1/payment-intent')) {
        return http.Response(
          jsonEncode(functionBody ?? _intent),
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
  return (remote: SupabaseOnlinePaymentRemoteDataSource(client), sent: sent);
}

void main() {
  test('Success: createIntent maps the success body', () async {
    final harness = _harness();
    final intent = await harness.remote.createIntent(
      sessionId: 55,
      plate: 'ABC123',
    );
    expect(intent.intentId, 9);
    expect(intent.reference, 'PM-1A2B3C4D5E6F');
    expect(intent.amount, 6000);
    expect(intent.graceMinutes, 15);
    expect(intent.checkoutUrl, contains('wompi'));
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['session'], 55);
    expect(body['plate'], 'ABC123');
  });

  test('Failure: a 503 maps PaymentsNotConfiguredError to a typed code', () {
    final harness = _harness(
      functionStatus: 503,
      functionBody: {'message': 'PaymentsNotConfiguredError'},
    );
    expect(
      () => harness.remote.createIntent(sessionId: 55, plate: 'ABC123'),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'PaymentsNotConfiguredError',
        ),
      ),
    );
  });

  test('Failure: a 429 maps PaymentThrottledError to a typed code', () {
    final harness = _harness(
      functionStatus: 429,
      functionBody: {'message': 'PaymentThrottledError'},
    );
    expect(
      () => harness.remote.createIntent(sessionId: 55, plate: 'ABC123'),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'PaymentThrottledError',
        ),
      ),
    );
  });

  test('Failure: a network drop becomes NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(
      () => harness.remote.createIntent(sessionId: 55, plate: 'ABC123'),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('Success: status returns null for an unknown reference', () async {
    final harness = _harness(rpcBody: null);
    final status = await harness.remote.status(
      reference: 'PM-UNKNOWN',
      plate: 'ABC123',
    );
    expect(status, isNull);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_reference'], 'PM-UNKNOWN');
    expect(body['p_plate'], 'ABC123');
  });

  test('Success: status parses the approved payload', () async {
    final harness = _harness(rpcBody: _status);
    final status = await harness.remote.status(
      reference: 'PM-1A2B3C4D5E6F',
      plate: 'ABC123',
    );
    expect(status, isNotNull);
    expect(status!.status, PaymentStatus.approved);
    expect(status.paidTotal, 6000);
    expect(status.graceUntil, DateTime.parse('2026-11-17T13:00:00.000Z'));
  });
}
