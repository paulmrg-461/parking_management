import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';
import 'package:parking_management/features/merchants/infrastructure/merchant_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _merchant = {
  'id': 1,
  'name': 'Cafe Uno',
  'benefit_kind': 'percentage',
  'benefit_value': 10,
  'max_amount': null,
  'billing_mode': 'merchant_paid',
  'daily_cap': null,
  'monthly_cap': null,
  'active': true,
  'used_today': 1,
  'used_month': 3,
  'pending_now': 2,
  'locked': false,
  'credentials_version': 1,
  'created_at': '2026-11-01T12:00:00.000Z',
};

({SupabaseMerchantRemoteDataSource remote, List<http.Request> sent})
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
  return (remote: SupabaseMerchantRemoteDataSource(client), sent: sent);
}

String _rpcName(http.Request request) =>
    request.url.path.split('/rpc/').last;

void main() {
  test('Success: list maps the merchant counters', () async {
    final harness = _harness(body: [_merchant]);
    final merchants = await harness.remote.list();

    expect(merchants.single.name, 'Cafe Uno');
    expect(merchants.single.usedToday, 1);
    expect(merchants.single.pendingNow, 2);
    expect(_rpcName(harness.sent.single), 'list_merchants');
  });

  test('Failure: a refused list keeps its code', () {
    final harness = _harness(status: 403, body: {'message': 'AdminRequiredError'});
    expect(
      () => harness.remote.list(),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'AdminRequiredError',
        ),
      ),
    );
  });

  test('Success: save sends the p_ params and parses credentials', () async {
    final harness = _harness(
      body: {
        'merchant': _merchant,
        'credentials': {
          'token': 'a' * 48,
          'pin': '123456',
          'link_path': '/validate?m=${'a' * 48}',
        },
      },
    );
    final result = await harness.remote.save(
      const MerchantDraft(
        name: 'Cafe Uno',
        kind: MerchantBenefitKind.percentage,
        value: 10,
      ),
    );

    expect(result.merchant.id, 1);
    expect(result.credentials?.pin, '123456');
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_name'], 'Cafe Uno');
    expect(body['p_benefit_kind'], 'percentage');
    expect(body['p_billing_mode'], 'merchant_paid');
    expect(body['p_id'], isNull);
  });

  test('Success: reset, delete, policy and revoke hit their RPCs', () async {
    var harness = _harness(
      body: {
        'merchant_id': 1,
        'pin': '654321',
        'token': null,
        'link_path': null,
      },
    );
    final credentials = await harness.remote.resetCredentials(1);
    expect(credentials.pin, '654321');
    expect(credentials.token, isNull);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_rotate_token'], false);

    harness = _harness(body: {'max_per_session': 2});
    expect(await harness.remote.savePolicy(2), 2);
    expect(_rpcName(harness.sent.single), 'set_merchant_policy');
  });

  test('Success: addValidation returns the refreshed quote', () async {
    final harness = _harness(
      body: {
        'validation_id': 5,
        'merchant_id': 1,
        'merchant_name': 'Cafe Uno',
        'status': 'pending',
        'quote': {
          'session_id': 3,
          'base_amount': 9000,
          'gross': 9000,
          'adjustments': [
            {
              'type': 'merchant',
              'ref_id': 5,
              'label': 'Cafe Uno',
              'kind': 'percentage',
              'amount': 4500,
            },
          ],
          'adjustments_total': 4500,
          'discount_amount': 0,
          'amount_due': 4500,
        },
      },
    );
    final quote = await harness.remote.addValidation(
      merchantId: 1,
      sessionId: 3,
    );

    expect(quote.amountDue, 4500);
    expect(quote.adjustments.single.refId, 5);
  });

  test('Success: settlement sends ISO dates and parses totals', () async {
    final harness = _harness(
      body: {
        'from': '2026-11-01',
        'to': '2026-11-30',
        'merchants': [],
        'totals': {
          'validations': 0,
          'applied': 0,
          'forfeited': 0,
          'revoked': 0,
          'discounted_amount': 0,
          'amount_owed': 0,
          'courtesy_amount': 0,
        },
      },
    );
    final settlement = await harness.remote.settlement(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
    );

    expect(settlement.totals.validations, 0);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_start_date'], '2026-11-01');
    expect(body['p_end_date'], '2026-11-30');
  });

  test('Failure: a network drop becomes NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(() => harness.remote.list(), throwsA(isA<NetworkFailure>()));
  });
}
