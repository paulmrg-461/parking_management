import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/features/public_booking/infrastructure/public_booking_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _availability = {
  'lot': {
    'id': 1,
    'name': 'Central',
    'address': 'Calle 1',
    'schedule': '24 h',
    'phone': '3001112233',
    'whatsapp': '3001112233',
    'logo_path': 'lot1/logo.png',
    'timezone': 'America/Bogota',
    'currency': 'COP',
  },
  'max_reservation_hours': 24,
  'categories': [
    {
      'id': 2,
      'name': 'car',
      'group': 'car',
      'category_capacity': 10,
      'group_capacity': 10,
      'occupied': 6,
      'reserved': 1,
      'available': 3,
      'is_full': false,
    },
  ],
};

const _reservation = {
  'id': 12,
  'plate': 'ABC123',
  'category_id': 2,
  'category_name': 'car',
  'reserved_until': '2026-11-09T14:00:00+00:00',
  'status': 'active',
  'lot': {
    'id': 1,
    'name': 'Central',
    'address': 'Calle 1',
    'phone': '3001112233',
    'whatsapp': '3001112233',
  },
};

({SupabasePublicBookingRemoteDataSource remote, List<http.Request> sent})
_harness() {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      final body = request.url.path.endsWith('/public_availability')
          ? _availability
          : _reservation;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (remote: SupabasePublicBookingRemoteDataSource(client), sent: sent);
}

void main() {
  test('Success: availability maps the lot and its categories', () async {
    final h = _harness();

    final availability = await h.remote.availability(1);

    expect(availability, isNotNull);
    expect(availability!.lotName, 'Central');
    expect(availability.categories.single.available, 3);
    expect(availability.logoUrl, contains('/object/public/branding/lot1/'));
    final request = h.sent.single;
    expect(request.url.path, endsWith('/rpc/public_availability'));
    expect(jsonDecode(request.body), {'p_lot_id': 1});
  });

  test('Success: cancelling sends the code, plate and phone', () async {
    final h = _harness();

    await h.remote.cancel(
      lotId: 1,
      reservationId: 12,
      plate: 'ABC123',
      phone: '3001112233',
    );

    final request = h.sent.single;
    expect(request.url.path, endsWith('/rpc/public_cancel_reservation'));
    expect(jsonDecode(request.body), {
      'p_lot_id': 1,
      'p_reservation_id': 12,
      'p_plate': 'ABC123',
      'p_customer_phone': '3001112233',
    });
  });

  test('Success: a reservation sends the form and returns the code', () async {
    final h = _harness();
    final until = DateTime.utc(2026, 11, 9, 14);

    final reservation = await h.remote.reserve(
      lotId: 1,
      plate: 'ABC123',
      categoryId: 2,
      until: until,
      phone: '3001112233',
      name: 'Ana',
    );

    expect(reservation.id, 12);
    expect(reservation.lotName, 'Central');
    final request = h.sent.single;
    expect(request.url.path, endsWith('/rpc/public_create_reservation'));
    expect(jsonDecode(request.body), {
      'p_lot_id': 1,
      'p_plate': 'ABC123',
      'p_category_id': 2,
      'p_until': until.toIso8601String(),
      'p_customer_name': 'Ana',
      'p_customer_phone': '3001112233',
    });
  });
}
