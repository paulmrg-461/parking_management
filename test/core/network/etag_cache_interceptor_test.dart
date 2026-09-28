import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/network/etag_cache_interceptor.dart';

import '../../helpers/fake_http.dart';

void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;
  late List<ResponseBody Function(RequestOptions)> replies;

  setUp(() {
    replies = [];
    adapter = FakeHttpAdapter((options) async => replies.removeAt(0)(options));
    dio = dioWith(adapter)
      ..interceptors.add(
        EtagCacheInterceptor(cacheablePaths: const {'/api/categories'}),
      );
  });

  String? ifNoneMatch(int request) =>
      adapter.requests[request].headers['If-None-Match'] as String?;

  test('Success: a 304 is answered from the cached body', () async {
    replies
      ..add(
        (_) => jsonBody(
          [
            {'id': 1, 'name': 'Carro'},
          ],
          200,
          headers: {
            'etag': ['W/"abc"'],
          },
        ),
      )
      ..add((_) => ResponseBody.fromString('', 304));

    await dio.get<List<dynamic>>('/api/categories');
    final second = await dio.get<List<dynamic>>('/api/categories');

    expect(ifNoneMatch(0), isNull);
    expect(ifNoneMatch(1), 'W/"abc"');
    expect(second.statusCode, 200);
    expect(second.data, [
      {'id': 1, 'name': 'Carro'},
    ]);
  });

  test('Failure: a 304 without a cached copy still fails', () async {
    replies.add((_) => ResponseBody.fromString('', 304));

    await expectLater(
      dio.get<List<dynamic>>('/api/categories'),
      throwsA(isA<DioException>()),
    );
  });

  test('Security: other paths and non-GET requests are never cached', () async {
    replies
      ..add(
        (_) => jsonBody(
          const {'id': 1},
          200,
          headers: {
            'etag': ['"v1"'],
          },
        ),
      )
      ..add((_) => jsonBody(const {'id': 1}, 200))
      ..add(
        (_) => jsonBody(
          const {'id': 2},
          201,
          headers: {
            'etag': ['"v2"'],
          },
        ),
      )
      ..add((_) => jsonBody(const [], 200));

    await dio.get<Object?>('/api/users');
    await dio.get<Object?>('/api/users');
    await dio.post<Object?>('/api/categories', data: const {'name': 'x'});
    await dio.get<Object?>('/api/categories');

    expect(ifNoneMatch(1), isNull);
    expect(ifNoneMatch(3), isNull);
  });

  test('Idempotent-Replayed responses are flagged, not treated as errors', () async {
    replies.add(
      (_) => jsonBody(
        const {'id': 9},
        201,
        headers: {
          'idempotent-replayed': ['true'],
        },
      ),
    );

    final response = await dio.post<Object?>('/api/check-ins');

    expect(isIdempotentReplay(response), isTrue);
  });
}
