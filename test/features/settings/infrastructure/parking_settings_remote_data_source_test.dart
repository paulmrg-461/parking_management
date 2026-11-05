import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:parking_management/features/settings/infrastructure/parking_settings_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _row = {
  'name': 'Lot One',
  'address': '',
  'schedule': '',
  'phone': '',
  'website': '',
  'whatsapp': '',
};

({SupabaseParkingSettingsRemoteDataSource remote, List<http.Request> sent})
_harness(int activeLot) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    headers: {'x-lot-id': '$activeLot'},
    httpClient: MockClient((request) async {
      sent.add(request);
      return http.Response(
        jsonEncode(_row),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  final lots = LotSession()..select(activeLot);
  return (
    remote: SupabaseParkingSettingsRemoteDataSource(client, lots),
    sent: sent,
  );
}

void main() {
  test('Success: patch without a lot targets the active lot', () async {
    final h = _harness(2);

    await h.remote.patch({'name': 'x'});

    expect(h.sent.single.url.queryParameters['lot_id'], 'eq.2');
    expect(h.sent.single.headers['x-lot-id'], '2');
  });

  test(
    'Security: patch for another lot filters AND sends that lot header',
    () async {
      final h = _harness(2);

      await h.remote.patch({'name': 'x'}, lotId: 1);

      expect(h.sent.single.url.queryParameters['lot_id'], 'eq.1');
      expect(h.sent.single.headers['x-lot-id'], '1');
      expect(jsonDecode(h.sent.single.body), {'name': 'x'});
    },
  );
}
