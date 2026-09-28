import 'dart:convert';

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';

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

ResponseBody _json(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _sessionJson = {
  'id': 1,
  'plate': 'XYZ999',
  'status': 'open',
  'entry_time': '2026-01-01T00:00:00',
  'photo_count': 0,
};

void main() {
  late Map<String, String> sentFields;
  late Map<String, dynamic> sentHeaders;
  late List<MapEntry<String, MultipartFile>> sentFiles;

  DioCheckInRemoteDataSource sourceReturning(Object body, int statusCode) {
    final dio = Dio();
    dio.httpClientAdapter = _FakeHttpAdapter((options) async {
      sentHeaders = options.headers;
      final form = options.data as FormData;
      sentFields = {for (final field in form.fields) field.key: field.value};
      sentFiles = form.files;
      return _json(body, statusCode);
    });
    return DioCheckInRemoteDataSource(dio);
  }

  test('Success: sends category_id, color and brand when new-vehicle data is given', () async {
    final source = sourceReturning(_sessionJson, 201);

    await source.createCheckIn(
      plate: 'XYZ999',
      photos: const [],
      newVehicle: const NewVehicleInfo(
        categoryId: 2,
        color: 'Blue',
        brand: 'Kia',
      ),
    );

    expect(sentFields, {
      'plate': 'XYZ999',
      'category_id': '2',
      'color': 'Blue',
      'brand': 'Kia',
    });
  });

  test('Success: omits vehicle fields when no new-vehicle data (and null optionals)', () async {
    final source = sourceReturning(_sessionJson, 201);

    await source.createCheckIn(plate: 'XYZ999', photos: const []);
    expect(sentFields, {'plate': 'XYZ999'});

    await source.createCheckIn(
      plate: 'XYZ999',
      photos: const [],
      newVehicle: const NewVehicleInfo(categoryId: 2),
    );
    expect(sentFields, {'plate': 'XYZ999', 'category_id': '2'});
  });

  test(
    'Failure: 422 surfaces the backend detail as a ValidationFailure',
    () async {
      final source = sourceReturning({
        'detail': 'Vehicle not registered: category_id is required',
      }, 422);

      await expectLater(
        source.createCheckIn(plate: 'XYZ999', photos: const []),
        throwsA(
          const ValidationFailure(
            'Vehicle not registered: category_id is required',
          ),
        ),
      );
    },
  );

  test(
    'Security: 409 duplicate open session surfaces backend detail, not a crash',
    () async {
      final source = sourceReturning({
        'detail': 'Vehicle already has an open session',
      }, 409);

      await expectLater(
        source.createCheckIn(plate: 'XYZ999', photos: const []),
        throwsA(const ValidationFailure('Vehicle already has an open session')),
      );
    },
  );

  test('Success: replays send the Idempotency-Key header', () async {
    final source = sourceReturning(_sessionJson, 201);

    await source.createCheckIn(
      plate: 'XYZ999',
      photos: const [],
      idempotencyKey: 'ref-1',
    );

    expect(sentHeaders['Idempotency-Key'], 'ref-1');
  });

  test(
    'Security: no Idempotency-Key header is invented for online calls',
    () async {
      final source = sourceReturning(_sessionJson, 201);

      await source.createCheckIn(plate: 'XYZ999', photos: const []);

      expect(sentHeaders.containsKey('Idempotency-Key'), isFalse);
    },
  );

  test(
    'Success: photos are sent as multipart bytes with image MIME types',
    () async {
      final source = sourceReturning(_sessionJson, 201);

      await source.createCheckIn(
        plate: 'XYZ999',
        photos: [
          XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: 'a.jpg',
            name: 'a.jpg',
          ),
          XFile.fromData(Uint8List.fromList([4]), path: 'b.png', name: 'b.png'),
        ],
      );

      expect(sentFiles.map((f) => f.key), ['photos', 'photos']);
      expect(sentFiles.first.value.length, 3);
      expect(sentFiles.first.value.contentType.toString(), 'image/jpeg');
      expect(sentFiles.last.value.contentType.toString(), 'image/png');
      expect(sentFiles.last.value.filename, 'photo_1.png');
    },
  );

  test(
    'Failure: 413 (photo too large) surfaces as a ValidationFailure',
    () async {
      final source = sourceReturning({'detail': 'Photo exceeds 5 MB'}, 413);

      await expectLater(
        source.createCheckIn(plate: 'XYZ999', photos: const []),
        throwsA(const ValidationFailure('Photo exceeds 5 MB')),
      );
    },
  );
}
