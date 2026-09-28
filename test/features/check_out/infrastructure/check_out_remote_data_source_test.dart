import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_out/infrastructure/check_out_remote_data_source.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}

const _receiptJson = {
  'id': 5,
  'plate': 'ABC123',
  'entry_time': '2026-01-01T08:00:00',
  'exit_time': '2026-01-01T10:00:00',
  'amount_charged': 6000,
  'ticket_number': 'TCK-000001',
};

void main() {
  late RequestOptions sent;

  DioCheckOutRemoteDataSource sourceReturning(
    Object body,
    int statusCode, {
    Map<String, List<String>> headers = const {},
  }) {
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpAdapter((options) async {
        sent = options;
        return ResponseBody.fromString(
          jsonEncode(body),
          statusCode,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            ...headers,
          },
        );
      });
    return DioCheckOutRemoteDataSource(dio);
  }

  test(
    'Success: replay sends client_exit_time and the Idempotency-Key header',
    () async {
      final source = sourceReturning(_receiptJson, 200);

      await source.checkOut(
        5,
        clientExitTime: DateTime.parse('2026-01-01T10:00:00.000'),
        idempotencyKey: 'k1',
      );

      expect(sent.headers['Idempotency-Key'], 'k1');
      expect(
        (sent.data as Map)['client_exit_time'],
        DateTime.parse('2026-01-01T10:00:00.000').toUtc().toIso8601String(),
      );
    },
  );

  test('Failure: 409 surfaces as a ValidationFailure', () async {
    final source = sourceReturning({'detail': 'Session already closed'}, 409);

    await expectLater(
      source.checkOut(5),
      throwsA(const ValidationFailure('Session already closed')),
    );
  });

  test('Security: online check-out sends no Idempotency-Key header', () async {
    final source = sourceReturning(_receiptJson, 200);

    await source.checkOut(5);

    expect(sent.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test(
    'Security: client_exit_time always carries a UTC offset (never naive)',
    () async {
      final source = sourceReturning(_receiptJson, 200);

      await source.checkOut(5, clientExitTime: DateTime(2026, 3, 1, 22, 30));

      final sentTime = (sent.data as Map)['client_exit_time'] as String;
      expect(sentTime, endsWith('Z'));
      expect(DateTime.parse(sentTime), DateTime(2026, 3, 1, 22, 30).toUtc());
    },
  );

  test(
    'Success: open sessions page sends limit/offset and reads X-Total-Count',
    () async {
      final source = sourceReturning(
        [
          {'id': 1, 'vehicle_id': 7, 'entry_time': '2026-01-01T08:00:00Z'},
        ],
        200,
        headers: {
          'x-total-count': ['80'],
        },
      );

      final page = await source.listOpenSessions(limit: 50, offset: 50);

      expect(sent.queryParameters, {'limit': 50, 'offset': 50});
      expect(page.items.single.vehicleId, 7);
      expect(page.total, 80);
    },
  );

  test('Failure: without X-Total-Count the page reports no total', () async {
    final source = sourceReturning(const <Object>[], 200);

    final page = await source.listOpenSessions(limit: 50, offset: 0);

    expect(page.total, isNull);
    expect(page.hasMoreAfter(0), isFalse);
  });
}
