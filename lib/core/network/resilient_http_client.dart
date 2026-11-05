import 'dart:async';

import 'package:http/http.dart' as http;

import 'network_metrics.dart';

/// HTTP client used by Supabase.
///
/// * every request gets a timeout (storage uploads are exempt: a 50 MB video
///   may legitimately take minutes);
/// * idempotent GET/HEAD requests are retried on timeouts, connection errors
///   and 502/503/504 with a small linear backoff;
/// * writes are never retried here — the RPC/outbox layer owns idempotency;
/// * counters feed the admin diagnostics panel.
class ResilientHttpClient extends http.BaseClient {
  ResilientHttpClient(
    this._inner, {
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  final http.Client _inner;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method.toUpperCase();
    final idempotent = method == 'GET' || method == 'HEAD';
    final upload =
        (method == 'POST' || method == 'PUT') &&
        request.url.path.contains('/storage/v1/object');

    var attempt = 0;
    while (true) {
      try {
        final outgoing = idempotent ? _clone(request) : request;
        final responseFuture = _inner.send(outgoing);
        final response = upload
            ? await responseFuture
            : await responseFuture.timeout(timeout);

        if (idempotent &&
            _retryableStatus(response.statusCode) &&
            attempt < maxRetries) {
          NetworkMetrics.retries++;
          attempt++;
          await _discard(response);
          await Future<void>.delayed(retryDelay * attempt);
          continue;
        }
        if (response.statusCode >= 500) {
          NetworkMetrics.failed++;
        }
        return response;
      } on TimeoutException {
        NetworkMetrics.timeouts++;
        if (!idempotent || attempt >= maxRetries) {
          NetworkMetrics.failed++;
          rethrow;
        }
        attempt++;
        await Future<void>.delayed(retryDelay * attempt);
      } on http.ClientException {
        NetworkMetrics.failed++;
        if (!idempotent || attempt >= maxRetries) {
          rethrow;
        }
        attempt++;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  /// GET/HEAD have no body, so a fresh request can be built for each attempt
  /// (the previous one was finalized and cannot be sent twice).
  http.BaseRequest _clone(http.BaseRequest request) {
    final clone = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    return clone;
  }

  Future<void> _discard(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } catch (_) {
      // A broken body must not hide the retry.
    }
  }

  static bool _retryableStatus(int status) =>
      status == 502 || status == 503 || status == 504;

  @override
  void close() => _inner.close();
}
