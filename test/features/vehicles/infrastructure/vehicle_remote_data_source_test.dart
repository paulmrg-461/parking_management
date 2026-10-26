import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';

import '../../../helpers/fake_http.dart';

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

ResponseBody _json(
  Object body,
  int statusCode, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

void main() {
  group('DioVehicleRemoteDataSource', () {
    test('list returns vehicles on success', () async {
      final dio = _dioWith(
        (options) async => _json([
          {
            'id': 1,
            'plate': 'ABC123',
            'category_id': 1,
            'color': 'red',
            'brand': 'Mazda',
          },
        ], 200),
      );
      final source = DioVehicleRemoteDataSource(dio);

      final vehicles = await source.list();

      expect(vehicles.single.plate, 'ABC123');
      expect(vehicles.single.color, 'red');
    });

    test('list walks every page instead of truncating at the first one', () async {
      final requests = <RequestOptions>[];
      final dio = _dioWith((options) async {
        requests.add(options);
        final offset =
            int.tryParse(options.uri.queryParameters['offset'] ?? '0') ?? 0;
        return _json([
          {
            'id': offset + 1,
            'plate': 'PLT00${offset + 1}',
            'category_id': 1,
            'color': null,
            'brand': null,
          },
        ], 200, headers: {'x-total-count': ['2']});
      });
      final source = DioVehicleRemoteDataSource(dio);

      final vehicles = await source.list();

      expect(vehicles, hasLength(2));
      expect(requests, hasLength(2));
      expect(requests.last.uri.queryParameters['offset'], '1');
    });

    test('create maps 403 to a non-retryable validation failure', () async {
      final dio = _dioWith(
        (options) async => _json({'detail': 'Forbidden'}, 403),
      );
      final source = DioVehicleRemoteDataSource(dio);

      expect(() => source.create({}), throwsA(isA<ValidationFailure>()));
    });

    test('list maps connection errors to a network failure', () async {
      final dio = _dioWith(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final source = DioVehicleRemoteDataSource(dio);

      expect(() => source.list(), throwsA(isA<NetworkFailure>()));
    });

    test(
      'Success: listPage sends limit/offset and reads X-Total-Count',
      () async {
        final adapter = FakeHttpAdapter(
          (_) async => jsonBody(
            [
              {'id': 1, 'plate': 'ABC123', 'category_id': 1},
            ],
            200,
            headers: {
              'x-total-count': ['75'],
            },
          ),
        );

        final page = await DioVehicleRemoteDataSource(dioWith(adapter))
            .listPage(limit: 50, offset: 50);

        expect(adapter.requests.single.queryParameters, {
          'limit': 50,
          'offset': 50,
        });
        expect(page.items.single.plate, 'ABC123');
        expect(page.total, 75);
      },
    );

    test(
      'Failure: listPage without X-Total-Count has no total (no more pages)',
      () async {
        final adapter = FakeHttpAdapter(
          (_) async => jsonBody(const <Object>[], 200),
        );

        final page = await DioVehicleRemoteDataSource(dioWith(adapter))
            .listPage(limit: 50, offset: 0);

        expect(page.total, isNull);
      },
    );

    test(
      'Security: a plate lookup never sends pagination parameters',
      () async {
        final adapter = FakeHttpAdapter(
          (_) async => jsonBody(const <Object>[], 200),
        );

        await DioVehicleRemoteDataSource(dioWith(adapter))
            .list(plate: 'ABC123');

        expect(adapter.requests.single.queryParameters, {'plate': 'ABC123'});
      },
    );
  });
}
