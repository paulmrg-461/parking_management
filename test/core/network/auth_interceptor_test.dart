import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/network/auth_interceptor.dart';
import 'package:parking_management/core/network/session_reader.dart';

class _FakeSessionReader implements SessionReader {
  _FakeSessionReader(this.token);

  String? token;

  @override
  Future<String?> currentToken() async => token;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode);

  final int statusCode;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'detail': 'x'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  _Harness({String? token, int statusCode = 200})
    : session = _FakeSessionReader(token),
      adapter = _RecordingAdapter(statusCode) {
    dio = Dio(BaseOptions(baseUrl: 'https://api.parking.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(session, () => unauthorizedCalls++));
  }

  final _FakeSessionReader session;
  final _RecordingAdapter adapter;
  late final Dio dio;
  int unauthorizedCalls = 0;

  String? lastAuthHeader() =>
      adapter.requests.last.headers['Authorization'] as String?;
}

void main() {
  group('AuthInterceptor', () {
    test('Success: attaches the stored bearer token to API requests', () async {
      final harness = _Harness(token: 'abc');

      await harness.dio.get('/api/vehicles');

      expect(harness.lastAuthHeader(), 'Bearer abc');
    });

    test(
      'Failure: a 401 on an authenticated request triggers logout',
      () async {
        final harness = _Harness(token: 'expired', statusCode: 401);

        await expectLater(
          harness.dio.get('/api/vehicles'),
          throwsA(isA<DioException>()),
        );

        expect(harness.unauthorizedCalls, 1);
      },
    );

    test(
      'Failure: a 401 on the login request does NOT trigger logout',
      () async {
        final harness = _Harness(statusCode: 401);

        await expectLater(
          harness.dio.post(
            '/api/auth/login',
            options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
          ),
          throwsA(isA<DioException>()),
        );

        expect(harness.unauthorizedCalls, 0);
      },
    );

    test('Failure: non-401 errors do not trigger logout', () async {
      final harness = _Harness(token: 'abc', statusCode: 403);

      await expectLater(
        harness.dio.get('/api/users'),
        throwsA(isA<DioException>()),
      );

      expect(harness.unauthorizedCalls, 0);
    });

    test('Security: no session means no Authorization header', () async {
      final harness = _Harness();

      await harness.dio.get('/api/vehicles');

      expect(harness.lastAuthHeader(), isNull);
    });

    test('Security: login request never carries a stale token', () async {
      final harness = _Harness(token: 'stale');

      await harness.dio.post(
        '/api/auth/login',
        options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
      );

      expect(harness.lastAuthHeader(), isNull);
    });

    test('Security: token is not leaked to a foreign origin', () async {
      final harness = _Harness(token: 'abc');

      await harness.dio.get('https://evil.example.com/steal');

      expect(harness.lastAuthHeader(), isNull);
    });
  });
}
