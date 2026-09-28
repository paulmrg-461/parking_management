import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/infrastructure/category_remote_data_source.dart';

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
  group('DioCategoryRemoteDataSource', () {
    test('list returns categories on success', () async {
      final dio = _dioWith(
        (options) async => _json([
          {'id': 1, 'name': 'carro'},
          {'id': 2, 'name': 'moto'},
        ], 200),
      );
      final source = DioCategoryRemoteDataSource(dio);

      final categories = await source.list();

      expect(categories.length, 2);
      expect(categories.first.name, 'carro');
    });

    test('create maps 403 to an authentication failure', () async {
      final dio = _dioWith(
        (options) async => _json({'detail': 'Forbidden'}, 403),
      );
      final source = DioCategoryRemoteDataSource(dio);

      expect(() => source.create('bus'), throwsA(isA<AuthenticationFailure>()));
    });

    test('list maps connection errors to a network failure', () async {
      final dio = _dioWith(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final source = DioCategoryRemoteDataSource(dio);

      expect(() => source.list(), throwsA(isA<NetworkFailure>()));
    });
  });
}
