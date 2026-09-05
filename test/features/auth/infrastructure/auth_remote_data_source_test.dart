import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/infrastructure/auth_remote_data_source.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

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
  group('DioAuthRemoteDataSource.login', () {
    test('returns a session with user and token on success', () async {
      final dio = _dioWith((options) async => _json({
            'access_token': 'abc',
            'user': {
              'id': 1,
              'username': 'juan',
              'display_name': 'Juan',
              'role': 'operator',
              'is_active': true,
            },
          }, 200));
      final source = DioAuthRemoteDataSource(dio);

      final session = await source.login('juan', '1234');

      expect(session.token, 'abc');
      expect(session.user.username, 'juan');
      expect(session.user.role.name, 'operator');
    });

    test('maps 401 to an authentication failure', () async {
      final dio = _dioWith(
        (options) async => _json({'detail': 'Invalid credentials'}, 401),
      );
      final source = DioAuthRemoteDataSource(dio);

      expect(
        () => source.login('juan', '0000'),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('maps connection errors to a network failure', () async {
      final dio = _dioWith(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final source = DioAuthRemoteDataSource(dio);

      expect(
        () => source.login('juan', '1234'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
