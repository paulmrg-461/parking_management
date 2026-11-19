import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';
import 'package:parking_management/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:parking_management/features/loyalty/infrastructure/loyalty_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

({SupabaseLoyaltyRemoteDataSource remote, List<http.Request> sent}) _harness({
  Object? body,
  int status = 200,
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
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (remote: SupabaseLoyaltyRemoteDataSource(client), sent: sent);
}

String _rpc(http.Request request) => request.url.path.split('/rpc/').last;

void main() {
  test('Success: status calls loyalty_plate_status with p_plate', () async {
    final harness = _harness(
      body: {
        'enabled': true,
        'plate': 'ABC123',
        'visits': 3,
        'required': 5,
        'next_visit': 4,
        'reward_count': 1,
        'redeem_mode': 'auto',
        'counted_today': false,
      },
    );
    final status = await harness.remote.status('ABC123');

    expect(status.visits, 3);
    expect(status.hasReward, isTrue);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_plate'], 'ABC123');
    expect(_rpc(harness.sent.single), 'loyalty_plate_status');
  });

  test('Success: saveSettings calls set_loyalty_settings with p_settings', () async {
    final harness = _harness(
      body: {
        'enabled': true,
        'visits_required': 5,
        'reward_kind': 'free_stay',
        'reward_max_amount': null,
        'reward_fixed_amount': 0,
        'min_amount': 0,
        'min_minutes': 0,
        'redeem_mode': 'auto',
        'stack_with_merchant': true,
        'reward_valid_days': 90,
      },
    );
    final settings = await harness.remote.saveSettings(
      const LoyaltySettings(enabled: true, visitsRequired: 5),
    );

    expect(settings.enabled, isTrue);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect((body['p_settings'] as Map)['visits_required'], 5);
    expect(_rpc(harness.sent.single), 'set_loyalty_settings');
  });

  test('Success: choose calls choose_loyalty_redemption', () async {
    final harness = _harness(
      body: {'session_id': 4, 'choice': 'redeem', 'reward_available': true},
    );
    await harness.remote.choose(sessionId: 4, choice: LoyaltyChoice.redeem);

    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_session_id'], 4);
    expect(body['p_choice'], 'redeem');
    expect(_rpc(harness.sent.single), 'choose_loyalty_redemption');
  });

  test('Success: accounts passes the search and parses rows', () async {
    final harness = _harness(
      body: [
        {
          'plate': 'ABC123',
          'progress': 3,
          'earned_total': 2,
          'redeemed_total': 1,
          'reward_count': 1,
          'last_counted_day': '2026-11-10',
        },
      ],
    );
    final accounts = await harness.remote.accounts(search: 'abc');

    expect(accounts.single.plate, 'ABC123');
    expect(accounts.single.rewardCount, 1);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_search'], 'abc');
  });

  test('Success: adjust calls adjust_loyalty_progress', () async {
    final harness = _harness(
      body: {'plate': 'ABC123', 'progress': 4, 'required': 5, 'delta': 1},
    );
    final result = await harness.remote.adjust(
      plate: 'ABC123',
      delta: 1,
      reason: 'Ajuste',
    );

    expect(result.progress, 4);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_plate'], 'ABC123');
    expect(body['p_delta'], 1);
    expect(body['p_reason'], 'Ajuste');
  });

  test('Success: report sends the dates only', () async {
    final harness = _harness(
      body: {
        'start_date': '2026-11-01',
        'end_date': '2026-11-30',
        'visits': {'counted': 3},
        'rewards': {'earned': 1},
      },
    );
    await harness.remote.report(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
    );

    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_start_date'], '2026-11-01');
    expect(body['p_end_date'], '2026-11-30');
  });

  test('Failure: a typed error becomes a Failure with its code', () {
    final harness = _harness(
      status: 400,
      body: {'message': 'InvalidLoyaltySettingsError'},
    );
    expect(
      () => harness.remote.saveSettings(const LoyaltySettings()),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'InvalidLoyaltySettingsError',
        ),
      ),
    );
  });

  test('Failure: a network drop maps to NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(() => harness.remote.status('ABC123'), throwsA(isA<NetworkFailure>()));
  });

  test('Security: an operator adjust maps AdminRequiredError', () async {
    final harness = _harness(
      status: 403,
      body: {'message': 'AdminRequiredError'},
    );
    expect(
      () => harness.remote.adjust(plate: 'ABC123', delta: 1, reason: 'X'),
      throwsA(
        isA<Failure>().having(
          (failure) => failure.code,
          'code',
          'AdminRequiredError',
        ),
      ),
    );
  });
}
