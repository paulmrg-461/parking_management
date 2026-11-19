import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/features/reservations/infrastructure/reservation_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Success: the board asks the RPC and parses the grace flag', () async {
    late Uri sent;
    final client = SupabaseClient(
      'http://localhost:8000',
      'anon',
      httpClient: MockClient((request) async {
        sent = request.url;
        return http.Response(
          jsonEncode([
            {
              'id': 12,
              'plate': 'WEB123',
              'category_id': 2,
              'category_name': 'car',
              'reserved_until': '2026-11-09T20:00:00+00:00',
              'status': 'active',
              'customer_name': 'Ana',
              'customer_phone': '3009998877',
              'source': 'public',
              'in_grace': true,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );

    final holds = await SupabaseReservationRemoteDataSource(client)
        .listActive();

    expect(holds.single.plate, 'WEB123');
    expect(holds.single.categoryName, 'car');
    expect(holds.single.isPublic, isTrue);
    expect(holds.single.customerPhone, '3009998877');
    expect(holds.single.inGrace, isTrue);
    // The grace window is the server's; the app only calls the RPC.
    expect(sent.path, endsWith('/rpc/list_active_reservations'));
  });
}
