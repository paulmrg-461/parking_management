import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/versioned_write.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _Handler = Future<http.Response> Function(http.Request request);

SupabaseClient _client(_Handler handler) => SupabaseClient(
  'http://localhost:8000',
  'anon',
  httpClient: MockClient(handler),
);

http.Response _json(Object body, http.Request request, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );

void main() {
  test(
    'Success: an update sends the id and version filters and returns the row',
    () async {
      late Uri url;
      final client = _client((request) async {
        url = request.url;
        return _json([
          {'id': 5, 'version': 8, 'color': 'blue'},
        ], request);
      });

      final row = await updateVersioned(
        client,
        'vehicles',
        payload: {'color': 'blue'},
        match: {'id': 5},
        baseVersion: 7,
      );

      expect(row['version'], 8);
      expect(url.queryParameters['id'], 'eq.5');
      expect(url.queryParameters['version'], 'eq.7');
    },
  );

  test(
    'Failure: a stale base throws VersionConflictFailure with the server row',
    () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        // 1) the update matches nothing, 2) the read returns the newer row.
        final isRead = request.method == 'GET';
        return _json(
          isRead
              ? [
                  {'id': 5, 'version': 9, 'color': 'red'},
                ]
              : <Object>[],
          request,
        );
      });

      await expectLater(
        updateVersioned(
          client,
          'vehicles',
          payload: {'color': 'blue'},
          match: {'id': 5},
          baseVersion: 7,
        ),
        throwsA(
          isA<VersionConflictFailure>().having(
            (failure) => failure.serverRow?['version'],
            'server version',
            9,
          ),
        ),
      );
      expect(calls, 2);
    },
  );

  test('Failure: a deleted row is a conflict with a null row', () async {
    final client = _client((request) async => _json(<Object>[], request));

    await expectLater(
      updateVersioned(
        client,
        'vehicles',
        payload: {'color': 'blue'},
        match: {'id': 5},
        baseVersion: 7,
      ),
      throwsA(
        isA<VersionConflictFailure>().having(
          (failure) => failure.serverRow,
          'server row',
          isNull,
        ),
      ),
    );
  });

  test(
    'Security: zero rows with the same version is a permission failure',
    () async {
      final client = _client(
        (request) async => _json(
          request.method == 'GET'
              ? [
                  {'id': 5, 'version': 7, 'color': 'red'},
                ]
              : <Object>[],
          request,
        ),
      );

      await expectLater(
        updateVersioned(
          client,
          'vehicles',
          payload: {'color': 'blue'},
          match: {'id': 5},
          baseVersion: 7,
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.code,
            'code',
            'PermissionDeniedError',
          ),
        ),
      );
    },
  );

  test(
    'Success: a null base sends no version filter and keeps NotFound',
    () async {
      late Uri url;
      final client = _client((request) async {
        url = request.url;
        return _json(<Object>[], request);
      });

      await expectLater(
        updateVersioned(
          client,
          'vehicles',
          payload: {'color': 'blue'},
          match: {'id': 5},
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.code,
            'code',
            'NotFoundError',
          ),
        ),
      );
      expect(url.queryParameters.containsKey('version'), isFalse);
    },
  );

  test('Success: deleting an already gone row returns normally', () async {
    final client = _client((request) async => _json(<Object>[], request));

    await deleteVersioned(client, 'vehicles', match: {'id': 5}, baseVersion: 7);
  });

  test('Failure: deleting a row another writer edited is a conflict', () async {
    final client = _client(
      (request) async => _json(
        request.method == 'GET'
            ? [
                {'id': 5, 'version': 9},
              ]
            : <Object>[],
        request,
      ),
    );

    await expectLater(
      deleteVersioned(client, 'vehicles', match: {'id': 5}, baseVersion: 7),
      throwsA(isA<VersionConflictFailure>()),
    );
  });

  test('Success: the lot header is sent when given', () async {
    late Map<String, String> headers;
    final client = _client((request) async {
      headers = request.headers;
      return _json([
        {'id': 5, 'version': 2},
      ], request);
    });

    await updateVersioned(
      client,
      'parking_settings',
      payload: {'name': 'Lot'},
      match: {'lot_id': 1},
      baseVersion: 1,
      lotHeader: 1,
    );

    expect(headers['x-lot-id'], '1');
  });

  test('Failure: a network error maps to NetworkFailure', () async {
    final client = _client(
      (request) async => throw http.ClientException('down'),
    );

    await expectLater(
      updateVersioned(
        client,
        'vehicles',
        payload: {'color': 'blue'},
        match: {'id': 5},
        baseVersion: 7,
      ),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
