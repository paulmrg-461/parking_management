import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';
import 'package:parking_management/features/evidence/infrastructure/session_evidence_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _rows = [
  {
    'id': 1,
    'file_path': 'abc/0.jpg',
    'kind': 'photo',
    'duration_seconds': null,
    'taken_at': '2026-11-09T10:00:00Z',
  },
  {
    'id': 2,
    'file_path': 'abc/1.mp4',
    'kind': 'video',
    'duration_seconds': 42,
    'taken_at': '2026-11-09T10:05:00Z',
  },
];

({SupabaseSessionEvidenceRemoteDataSource remote, List<http.Request> sent})
_harness({bool denySigning = false, int listStatus = 200}) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      final json = {'content-type': 'application/json'};
      if (request.url.path.contains('/rest/v1/evidence_photos')) {
        return http.Response(
          listStatus == 200 ? jsonEncode(_rows) : '{"message":"boom"}',
          listStatus,
          headers: json,
          request: request,
        );
      }
      if (request.url.path.contains('/object/sign/')) {
        if (denySigning) {
          return http.Response(
            '{"message":"denied"}',
            403,
            headers: json,
            request: request,
          );
        }
        return http.Response(
          jsonEncode({'signedURL': '/object/sign/evidence/abc/0.jpg?token=t'}),
          200,
          headers: json,
          request: request,
        );
      }
      return http.Response('{}', 200, headers: json, request: request);
    }),
  );
  return (remote: SupabaseSessionEvidenceRemoteDataSource(client), sent: sent);
}

void main() {
  test('Success: lists the session evidence and signs each file', () async {
    final h = _harness();

    final items = await h.remote.listForSession(7);

    expect(items, hasLength(2));
    expect(items.first.kind, EvidenceKind.photo);
    expect(items.first.isAvailable, isTrue);
    expect(items.first.url, contains('token=t'));
    expect(items.last.isVideo, isTrue);
    expect(items.last.durationSeconds, 42);

    final list = h.sent.firstWhere(
      (request) => request.url.path.contains('/rest/v1/evidence_photos'),
    );
    expect(list.url.queryParameters['session_id'], 'eq.7');
    expect(
      h.sent.where((request) => request.url.path.contains('/object/sign/')),
      hasLength(2),
    );
  });

  test(
    'Failure: a refused signature keeps the row but marks it unavailable',
    () async {
      final h = _harness(denySigning: true);

      final items = await h.remote.listForSession(7);

      expect(items, hasLength(2));
      expect(items.every((item) => !item.isAvailable), isTrue);
    },
  );

  test('Failure: a failed listing surfaces a mapped Failure', () async {
    final h = _harness(listStatus: 500);

    expect(() => h.remote.listForSession(7), throwsA(isA<Failure>()));
  });
}
