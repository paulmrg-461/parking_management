import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/dio_error_mapper.dart';

DioException _errorWith(
  int statusCode,
  Object? data, {
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/api/check-ins');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
      headers: Headers.fromMap(headers),
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('mapDioError', () {
    test('Success: uses the backend detail string for 404/409/422', () {
      expect(
        mapDioError(_errorWith(404, {'detail': 'Category not found'})),
        const ValidationFailure('Category not found'),
      );
      expect(
        mapDioError(
          _errorWith(409, {'detail': 'Vehicle already has an open session'}),
        ),
        const ValidationFailure('Vehicle already has an open session'),
      );
      expect(
        mapDioError(
          _errorWith(422, {
            'detail': 'Vehicle not registered: category_id is required',
          }),
        ),
        const ValidationFailure(
          'Vehicle not registered: category_id is required',
        ),
      );
    });

    test('Failure: falls back to generic texts when detail is missing', () {
      expect(
        mapDioError(_errorWith(404, null)),
        const ValidationFailure('Not found'),
      );
      expect(
        mapDioError(_errorWith(409, 'oops')),
        const ValidationFailure('Conflict'),
      );
      expect(
        mapDioError(_errorWith(422, {})),
        const ValidationFailure('Invalid request'),
      );
      expect(
        mapDioError(_errorWith(500, {'detail': 'boom'})),
        isA<NetworkFailure>(),
      );
    });

    test(
      'Security: non-string detail (e.g. pydantic error list) is not surfaced',
      () {
        final failure = mapDioError(
          _errorWith(422, {
            'detail': [
              {
                'loc': ['body', 'plate'],
                'msg': 'field required',
                'input': 'secret',
              },
            ],
          }),
        );

        expect(failure, const ValidationFailure('Invalid request'));
      },
    );

    test(
      'Security: 401/403 keep generic auth messages regardless of detail',
      () {
        expect(
          mapDioError(_errorWith(401, {'detail': 'user admin not found'})),
          const AuthenticationFailure('Invalid credentials'),
        );
        expect(
          mapDioError(_errorWith(403, {'detail': 'role x'})),
          const AuthenticationFailure('Forbidden'),
        );
      },
    );
    test(
      'Success: 5xx, 429 and read timeouts are retryable ServerFailures',
      () {
        expect(mapDioError(_errorWith(503, null)), isA<ServerFailure>());
        expect(mapDioError(_errorWith(429, null)), isA<ServerFailure>());
        final timeout = DioException(
          requestOptions: RequestOptions(path: '/api/check-ins'),
          type: DioExceptionType.receiveTimeout,
        );
        expect(mapDioError(timeout), isA<ServerFailure>());
      },
    );

    test(
      'Failure: no connection is a plain NetworkFailure, not a ServerFailure',
      () {
        final offline = DioException(
          requestOptions: RequestOptions(path: '/api/check-ins'),
          type: DioExceptionType.connectionError,
        );
        final failure = mapDioError(offline);
        expect(failure, isA<NetworkFailure>());
        expect(failure, isNot(isA<ServerFailure>()));
      },
    );

    test('Security: other 4xx are non-retryable validation failures', () {
      expect(
        mapDioError(_errorWith(400, null)),
        const ValidationFailure('Request rejected'),
      );
      expect(
        mapDioError(_errorWith(413, {'detail': 'Too big'})),
        const ValidationFailure('Too big'),
      );
    });

    test('Success: carries the backend error code alongside the detail', () {
      final failure = mapDioError(
        _errorWith(409, {
          'detail': 'Vehicle already has an open session',
          'code': 'duplicate_open_session',
        }),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Vehicle already has an open session');
      expect(failure.code, 'duplicate_open_session');
    });

    test('Success: 429 surfaces the detail and minutes from Retry-After', () {
      final failure = mapDioError(
        _errorWith(
          429,
          {'detail': 'Too many attempts, try later'},
          headers: {
            'retry-after': ['150'],
          },
        ),
      );

      expect(failure, isA<RateLimitedFailure>());
      expect(failure, isA<ServerFailure>());
      final limited = failure as RateLimitedFailure;
      expect(limited.retryAfter, const Duration(seconds: 150));
      expect(limited.message, contains('Too many attempts, try later'));
      expect(limited.message, contains('3 min'));
    });

    test('Failure: 429 without Retry-After or detail falls back gently', () {
      final failure = mapDioError(_errorWith(429, null));

      expect(failure, isA<RateLimitedFailure>());
      expect((failure as RateLimitedFailure).retryAfter, isNull);
      expect(failure.message, 'Too many attempts, try later');
    });

    test('Security: malformed Retry-After and non-string code are ignored', () {
      final failure = mapDioError(
        _errorWith(
          429,
          {'detail': 'Too many attempts, try later', 'code': 42},
          headers: {
            'retry-after': ['<script>'],
          },
        ),
      );

      expect((failure as RateLimitedFailure).retryAfter, isNull);
      expect(failure.code, isNull);
      expect(failure.message, isNot(contains('<script>')));
    });

    test('Failure: 413 without detail is a ValidationFailure about size', () {
      final failure = mapDioError(_errorWith(413, null));

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Payload too large');
    });
  });
}
