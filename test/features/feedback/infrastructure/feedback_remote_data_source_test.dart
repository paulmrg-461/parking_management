import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/feedback/infrastructure/feedback_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _invite = {
  'lot_id': 1,
  'lot_name': 'Parqueadero Central',
  'rateable': true,
  'rated': false,
  'rating': null,
};

const _submitted = {'rating': 4, 'created_at': '2026-11-17T12:00:00Z'};

const _summary = {
  'days': 30,
  'start_date': '2026-10-19',
  'end_date': '2026-11-17',
  'timezone': 'America/Bogota',
  'total': 2,
  'average_x10': 45,
  'closed_sessions': 20,
  'response_rate_bp': 1000,
  'low_count': 0,
  'distribution': {'1': 0, '2': 0, '3': 0, '4': 1, '5': 1},
  'recent': <Object>[],
};

({SupabaseFeedbackRemoteDataSource remote, List<http.Request> sent}) _harness({
  int status = 200,
  Object? body,
  bool nullBody = false,
}) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost:8000',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      final path = request.url.path;
      final payload = path.endsWith('/public_feedback_session')
          ? _invite
          : path.endsWith('/public_submit_feedback')
          ? _submitted
          : _summary;
      return http.Response(
        nullBody ? 'null' : jsonEncode(body ?? payload),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return (remote: SupabaseFeedbackRemoteDataSource(client), sent: sent);
}

void main() {
  test(
    'Success: lookup sends the session and plate to the public RPC',
    () async {
      final h = _harness();

      final invite = await h.remote.invite(sessionId: 7, plate: ' abc 123 ');

      expect(invite, isNotNull);
      expect(invite!.lotName, 'Parqueadero Central');
      final request = h.sent.single;
      expect(request.url.path, endsWith('/rpc/public_feedback_session'));
      expect(jsonDecode(request.body), {
        'p_session_id': 7,
        'p_plate': ' abc 123 ',
      });
    },
  );

  test('Success: an unknown session returns null (no error)', () async {
    final h = _harness(nullBody: true);

    expect(await h.remote.invite(sessionId: 7, plate: 'ABC123'), isNull);
  });

  test('Success: submit sends rating and trimmed comment', () async {
    final h = _harness();

    final rating = await h.remote.submit(
      sessionId: 7,
      plate: 'ABC123',
      rating: 4,
      comment: 'Buen servicio',
    );

    expect(rating, 4);
    final request = h.sent.single;
    expect(request.url.path, endsWith('/rpc/public_submit_feedback'));
    expect(jsonDecode(request.body), {
      'p_session_id': 7,
      'p_plate': 'ABC123',
      'p_rating': 4,
      'p_comment': 'Buen servicio',
    });
  });

  test('Failure: a duplicate submission is a typed failure', () async {
    final h = _harness(
      status: 400,
      body: {'message': 'FeedbackAlreadyError', 'code': 'P0001'},
    );

    await expectLater(
      h.remote.submit(sessionId: 7, plate: 'ABC123', rating: 4, comment: ''),
      throwsA(
        isA<ValidationFailure>().having(
          (failure) => failure.code,
          'code',
          'FeedbackAlreadyError',
        ),
      ),
    );
  });

  test('Failure: a network error becomes NetworkFailure', () async {
    final client = SupabaseClient(
      'http://localhost:8000',
      'anon',
      httpClient: MockClient((_) async => throw http.ClientException('down')),
    );

    await expectLater(
      SupabaseFeedbackRemoteDataSource(client).summary(30),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test(
    'Success: the summary sends the period and parses the figures',
    () async {
      final h = _harness();

      final summary = await h.remote.summary(7);

      expect(summary.total, 2);
      expect(summary.averageX10, 45);
      expect(summary.countFor(5), 1);
      expect(jsonDecode(h.sent.single.body), {'p_days': 7});
    },
  );
}
