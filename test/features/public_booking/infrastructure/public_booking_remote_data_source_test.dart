import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
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
_harness({int status = 200, Object? errorBody}) {
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
        jsonEncode(errorBody ?? body),
        status,
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

  test(
    'Success: the lookup sends the code and phone and maps the hold',
    () async {
      final h = _harness();

      final found = await h.remote.lookup(
        lotId: 1,
        reservationId: 12,
        phone: '3001112233',
      );

      expect(found?.plate, 'ABC123');
      expect(found?.categoryName, 'car');
      final request = h.sent.single;
      expect(request.url.path, endsWith('/rpc/public_reservation_lookup'));
      expect(jsonDecode(request.body), {
        'p_lot_id': 1,
        'p_reservation_id': 12,
        'p_customer_phone': '3001112233',
      });
    },
  );

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

  test(
    'Success: a booking with a captcha token goes through the Edge Function',
    () async {
      final h = _harness();
      final until = DateTime.utc(2026, 11, 9, 14);

      final reservation = await h.remote.reserve(
        lotId: 1,
        plate: 'ABC123',
        categoryId: 2,
        until: until,
        phone: '3001112233',
        name: 'Ana',
        captchaToken: 'token-1',
      );

      expect(reservation.id, 12);
      final request = h.sent.single;
      expect(request.url.path, endsWith('/functions/v1/public-booking'));
      expect(jsonDecode(request.body), {
        'lot_id': 1,
        'plate': 'ABC123',
        'category_id': 2,
        'until': until.toIso8601String(),
        'name': 'Ana',
        'phone': '3001112233',
        'captcha_token': 'token-1',
      });
    },
  );

  test('Failure: a throttled RPC maps to its typed code', () async {
    final h = _harness(
      status: 400,
      errorBody: {'code': 'P0001', 'message': 'BookingThrottledError'},
    );

    await expectLater(
      h.remote.reserve(
        lotId: 1,
        plate: 'ABC123',
        categoryId: 2,
        until: DateTime.utc(2026, 11, 9, 14),
        phone: '3001112233',
        name: 'Ana',
      ),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'BookingThrottledError',
        ),
      ),
    );
  });

  test('Failure: the function throttle (429) keeps its typed code', () async {
    final h = _harness(
      status: 429,
      errorBody: {'message': 'BookingThrottledError'},
    );

    await expectLater(
      h.remote.reserve(
        lotId: 1,
        plate: 'ABC123',
        categoryId: 2,
        until: DateTime.utc(2026, 11, 9, 14),
        phone: '3001112233',
        name: 'Ana',
        captchaToken: 'token-1',
      ),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'BookingThrottledError',
        ),
      ),
    );
  });

  test('Security: a token the function rejects is a typed refusal', () async {
    final h = _harness(
      status: 403,
      errorBody: {'message': 'CaptchaFailedError'},
    );

    await expectLater(
      h.remote.reserve(
        lotId: 1,
        plate: 'ABC123',
        categoryId: 2,
        until: DateTime.utc(2026, 11, 9, 14),
        phone: '3001112233',
        name: 'Ana',
        captchaToken: 'forged',
      ),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'CaptchaFailedError',
        ),
      ),
    );
    expect(h.sent.single.url.path, endsWith('/functions/v1/public-booking'));
  });

  test(
    'Security: a direct call refused by the lot asks for the captcha',
    () async {
      final h = _harness(
        status: 400,
        errorBody: {'code': 'P0001', 'message': 'CaptchaRequiredError'},
      );

      await expectLater(
        h.remote.reserve(
          lotId: 1,
          plate: 'ABC123',
          categoryId: 2,
          until: DateTime.utc(2026, 11, 9, 14),
          phone: '3001112233',
          name: 'Ana',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.code,
            'code',
            'CaptchaRequiredError',
          ),
        ),
      );
    },
  );

  test(
    'Failure: a function outage without a typed code is a server failure',
    () async {
      final h = _harness(status: 503, errorBody: {'message': 'gateway down'});

      await expectLater(
        h.remote.reserve(
          lotId: 1,
          plate: 'ABC123',
          categoryId: 2,
          until: DateTime.utc(2026, 11, 9, 14),
          phone: '3001112233',
          name: 'Ana',
          captchaToken: 'token-1',
        ),
        throwsA(isA<ServerFailure>()),
      );
    },
  );
}
