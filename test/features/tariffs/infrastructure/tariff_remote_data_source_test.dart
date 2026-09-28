import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_remote_data_source.dart';

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

Dio _dioWith(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = Dio();
  dio.httpClientAdapter = _FakeHttpAdapter(handler);
  return dio;
}

ResponseBody _json(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group('DioTariffRemoteDataSource', () {
    test('list returns tariffs on success', () async {
      final dio = _dioWith(
        (options) async => _json([
          {
            'id': 1,
            'category_id': 1,
            'type': 'nightly',
            'amount': 5000,
            'start_time': '18:00',
            'end_time': '06:00',
            'active': true,
          },
        ], 200),
      );
      final source = DioTariffRemoteDataSource(dio);

      final tariffs = await source.list();

      expect(tariffs.single.type.name, 'nightly');
      expect(tariffs.single.startTime, '18:00');
    });

    test('create maps 403 to an authentication failure', () async {
      final dio = _dioWith(
        (options) async => _json({'detail': 'Forbidden'}, 403),
      );
      final source = DioTariffRemoteDataSource(dio);

      expect(() => source.create({}), throwsA(isA<AuthenticationFailure>()));
    });

    test('list maps connection errors to a network failure', () async {
      final dio = _dioWith(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final source = DioTariffRemoteDataSource(dio);

      expect(() => source.list(), throwsA(isA<NetworkFailure>()));
    });
  });
}
