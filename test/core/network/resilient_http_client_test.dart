import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/network/network_metrics.dart';
import 'package:parking_management/core/network/resilient_http_client.dart';

void main() {
  setUp(NetworkMetrics.reset);

  test('Success: passes a 200 through unchanged', () async {
    final client = ResilientHttpClient(
      MockClient((_) async => http.Response('ok', 200)),
      retryDelay: Duration.zero,
    );

    final response = await client.get(Uri.parse('https://example.test/rest'));

    expect(response.statusCode, 200);
    expect(NetworkMetrics.retries, 0);
  });

  test('Success: retries idempotent GET on 503', () async {
    var calls = 0;
    final client = ResilientHttpClient(
      MockClient((_) async {
        calls++;
        return http.Response('', calls == 1 ? 503 : 200);
      }),
      retryDelay: Duration.zero,
    );

    final response = await client.get(Uri.parse('https://example.test/rest'));

    expect(response.statusCode, 200);
    expect(calls, 2);
    expect(NetworkMetrics.retries, 1);
  });

  test('Security: writes are never retried by the transport', () async {
    var calls = 0;
    final client = ResilientHttpClient(
      MockClient((_) async {
        calls++;
        return http.Response('', 503);
      }),
      retryDelay: Duration.zero,
    );

    final response = await client.post(
      Uri.parse('https://example.test/rest/v1/rpc/check_in'),
      body: '{}',
    );

    expect(response.statusCode, 503);
    expect(calls, 1);
    expect(NetworkMetrics.retries, 0);
  });

  test('Failure: a persistent timeout surfaces after the retries', () async {
    final client = ResilientHttpClient(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('', 200);
      }),
      timeout: const Duration(milliseconds: 5),
      maxRetries: 1,
      retryDelay: Duration.zero,
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/rest')),
      throwsA(isA<TimeoutException>()),
    );
    expect(NetworkMetrics.timeouts, 2);
    expect(NetworkMetrics.failed, greaterThanOrEqualTo(1));
  });
}
