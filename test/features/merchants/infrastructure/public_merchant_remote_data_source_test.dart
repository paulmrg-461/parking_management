import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_validation_result.dart';
import 'package:parking_management/features/merchants/infrastructure/public_merchant_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabasePublicMerchantRemoteDataSource remote, List<http.Request> sent})
_harness({Object? body, int status = 200, bool networkError = false}) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      if (networkError) {
        throw http.ClientException('offline', request.url);
      }
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (
    remote: SupabasePublicMerchantRemoteDataSource(client),
    sent: sent,
  );
}

void main() {
  test('Success: portal returns the public identity', () async {
    final harness = _harness(
      body: {
        'merchant_name': 'Cafe Uno',
        'benefit_kind': 'fixed_amount',
        'benefit_value': 5000,
        'max_amount': 2000,
        'lot_name': 'Central',
        'locked_until': null,
      },
    );
    final portal = await harness.remote.portal('a' * 48);

    expect(portal?.merchantName, 'Cafe Uno');
    expect(portal?.kind, MerchantBenefitKind.fixedAmount);
    expect(portal?.isLocked, isFalse);
  });

  test('Failure: an unknown token returns null', () async {
    final harness = _harness(body: null);
    expect(await harness.remote.portal('a' * 48), isNull);
  });

  test('Success: validate maps the three answers', () async {
    var harness = _harness(
      body: {
        'status': 'registered',
        'merchant_name': 'Cafe Uno',
        'benefit_kind': 'percentage',
        'benefit_value': 10,
      },
    );
    expect(
      await harness.remote.validate(
        token: 'a' * 48,
        pin: '123456',
        plate: 'ABC123',
      ),
      isA<ValidationRegistered>(),
    );

    harness = _harness(body: {'status': 'invalid_pin', 'attempts_left': 4});
    final invalid = await harness.remote.validate(
      token: 'a' * 48,
      pin: '000000',
      plate: 'ABC123',
    );
    expect((invalid as ValidationInvalidPin).attemptsLeft, 4);

    harness = _harness(
      body: {
        'status': 'locked',
        'locked_until': '2026-11-17T12:30:00.000Z',
      },
    );
    final locked = await harness.remote.validate(
      token: 'a' * 48,
      pin: '000000',
      plate: 'ABC123',
    );
    expect((locked as ValidationLocked).until, DateTime.utc(2026, 11, 17, 12, 30));
  });

  test('Failure: a typed refusal keeps its code', () {
    final harness = _harness(
      status: 400,
      body: {'message': 'SessionNotFoundError'},
    );
    expect(
      () => harness.remote.validate(
        token: 'a' * 48,
        pin: '123456',
        plate: 'ZZZ999',
      ),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'SessionNotFoundError',
        ),
      ),
    );
  });

  test('Failure: a network drop becomes NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(
      () => harness.remote.portal('a' * 48),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
