import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/features/check_in/infrastructure/check_in_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ref = '11111111-2222-3333-4444-555555555555';

/// Records storage uploads and the RPC call; uploads answer [uploadStatus],
/// the RPC fails with 500 (the paths are what matters here).
class _Backend {
  _Backend({this.uploadStatus = 200});

  final int uploadStatus;
  final List<String> calls = [];

  SupabaseCheckInRemoteDataSource remote() => SupabaseCheckInRemoteDataSource(
    SupabaseClient(
      'http://localhost:8000',
      'anon',
      httpClient: MockClient(_handle),
    ),
  );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    calls.add(path);
    final upload = path.contains('/storage/v1/object/');
    final status = upload ? uploadStatus : 500;
    final body = upload && status == 409
        ? {'statusCode': '409', 'error': 'Duplicate', 'message': 'exists'}
        : {'Key': 'ok', 'message': 'boom'};
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  List<String> get uploads => [
    for (final call in calls)
      if (call.contains('/storage/v1/object/evidence/'))
        call.split('/storage/v1/object/evidence/').last,
  ];
}

XFile _file(String name, [String? mimeType]) => XFile.fromData(
  Uint8List.fromList(const [1, 2, 3]),
  name: name,
  path: name,
  mimeType: mimeType,
);

Future<void> _checkIn(_Backend backend) => backend
    .remote()
    .createCheckIn(
      plate: 'ABC123',
      photos: [_file('a.jpg'), _file('b.png', 'image/png')],
      video: _file('clip.mp4'),
      idempotencyKey: _ref,
    )
    .then((_) {}, onError: (Object _) {});

void main() {
  test('Success: evidence names are deterministic per client_ref', () async {
    final backend = _Backend();

    await _checkIn(backend);
    await _checkIn(backend);

    expect(backend.uploads, [
      '$_ref/0.jpg',
      '$_ref/1.png',
      '$_ref/video.mp4',
      '$_ref/0.jpg',
      '$_ref/1.png',
      '$_ref/video.mp4',
    ]);
  });

  test(
    'Failure: a replay hitting 409 (already uploaded) still calls check_in',
    () async {
      final backend = _Backend(uploadStatus: 409);

      await _checkIn(backend);

      expect(backend.calls.last, endsWith('/rest/v1/rpc/check_in'));
    },
  );

  test(
    'Security: every upload happens BEFORE check_in references it',
    () async {
      final backend = _Backend();

      await _checkIn(backend);

      final rpc = backend.calls.indexWhere((c) => c.endsWith('/rpc/check_in'));
      expect(rpc, backend.calls.length - 1);
      expect(backend.uploads, hasLength(3));
    },
  );
}
