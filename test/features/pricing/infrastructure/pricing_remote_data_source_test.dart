import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_rule.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_settings.dart';
import 'package:parking_management/features/pricing/infrastructure/pricing_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _rule = {
  'id': 1,
  'name': 'Alta ocupacion',
  'active': true,
  'priority': 200,
  'group': 'car',
  'min_occupancy_pct': 80,
  'max_occupancy_pct': 100,
  'weekdays': null,
  'from_time': null,
  'to_time': null,
  'multiplier_bps': 12000,
  'surcharge_amount': 0,
};

({SupabasePricingRemoteDataSource remote, List<http.Request> sent})
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
  return (remote: SupabasePricingRemoteDataSource(client), sent: sent);
}

String _rpc(http.Request request) => request.url.path.split('/rpc/').last;

void main() {
  test('Success: listRules parses the list', () async {
    final harness = _harness(body: [_rule]);
    final rules = await harness.remote.listRules();

    expect(rules.single.name, 'Alta ocupacion');
    expect(rules.single.multiplierBps, 12000);
    expect(_rpc(harness.sent.single), 'list_pricing_rules');
  });

  test('Success: saveRule sends the p_ params', () async {
    final harness = _harness(body: _rule);
    final rule = await harness.remote.saveRule(
      const PricingRuleDraft(
        name: 'Alta ocupacion',
        priority: 200,
        group: 'car',
        minOccupancyPct: 80,
        maxOccupancyPct: 100,
        multiplierBps: 12000,
      ),
    );

    expect(rule.id, 1);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_name'], 'Alta ocupacion');
    expect(body['p_multiplier_bps'], 12000);
    expect(_rpc(harness.sent.single), 'save_pricing_rule');
  });

  test('Failure: a duplicate keeps its code', () {
    final harness = _harness(
      status: 400,
      body: {'message': 'DuplicatePricingRuleError'},
    );
    expect(
      () => harness.remote.saveRule(const PricingRuleDraft(name: 'X')),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'DuplicatePricingRuleError',
        ),
      ),
    );
  });

  test('Success: settings round trip', () async {
    final harness = _harness(
      body: {
        'enabled': true,
        'floor_bps': 9000,
        'ceiling_bps': 20000,
        'round_to': 100,
      },
    );
    final settings = await harness.remote.saveSettings(
      const PricingSettings(
        enabled: true,
        floorBps: 9000,
        ceilingBps: 20000,
        roundTo: 100,
      ),
    );

    expect(settings.ceilingBps, 20000);
    final body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_floor_bps'], 9000);
    expect(_rpc(harness.sent.single), 'set_pricing_settings');
  });

  test('Success: simulate sends the candidate rules only when given', () async {
    final harness = _harness(
      body: {
        'days': 30,
        'sessions_considered': 0,
        'by_rule': [],
        'by_hour': [],
      },
    );
    await harness.remote.simulate(days: 30);
    var body = jsonDecode(harness.sent.single.body) as Map;
    expect(body['p_rules'], isNull);

    await harness.remote.simulate(
      days: 7,
      candidates: const [PricingRuleDraft(name: 'Candidata', multiplierBps: 12000)],
    );
    body = jsonDecode(harness.sent.last.body) as Map;
    expect((body['p_rules'] as List).single['name'], 'Candidata');
  });

  test('Failure: a network drop becomes NetworkFailure', () {
    final harness = _harness(networkError: true);
    expect(() => harness.remote.listRules(), throwsA(isA<NetworkFailure>()));
  });
}
