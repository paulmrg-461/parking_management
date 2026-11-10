import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/features/reservations/domain/entities/reservation.dart';
import 'package:parking_management/features/reservations/infrastructure/reservation_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Success: active holds include the grace window and parse the contact',
    () async {
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
                'reserved_until': '2026-11-09T20:00:00+00:00',
                'status': 'active',
                'customer_name': 'Ana',
                'customer_phone': '3009998877',
                'source': 'public',
                'categories': {'name': 'car'},
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      final before = DateTime.now().toUtc();
      final holds = await SupabaseReservationRemoteDataSource(client)
          .listActive();

      expect(holds.single.plate, 'WEB123');
      expect(holds.single.isPublic, isTrue);
      expect(holds.single.customerPhone, '3009998877');

      final filter = sent.queryParameters['reserved_until'];
      expect(filter, startsWith('gt.'));
      final threshold = DateTime.parse(filter!.substring(3));
      // The board keeps holds that are inside the grace window, so the lower
      // bound is `now - grace` (a hold that ended 5 minutes ago still blocks a
      // slot until SQL drops it).
      final expected = before.subtract(Reservation.graceWindow);
      expect(
        threshold.difference(expected).inSeconds.abs() <= 5,
        isTrue,
        reason: 'threshold was $threshold, expected around $expected',
      );
    },
  );
}
