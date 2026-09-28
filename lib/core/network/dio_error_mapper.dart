import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Maps a [DioException] to a domain [Failure]. For 4xx the backend
/// `detail` string (and optional `code`) is surfaced when present (FastAPI
/// `HTTPException`); any other shape (e.g. pydantic's error list) falls back
/// to a generic text so raw request data is never echoed to the UI.
///
/// - no response (offline, DNS, connect timeout) → [NetworkFailure]
/// - 429 → [RateLimitedFailure] (retryable, with `Retry-After`)
/// - 5xx / read-send timeout → [ServerFailure] (retryable)
/// - other 4xx → [ValidationFailure] (non-retryable)
Failure mapDioError(DioException error) {
  final response = error.response;
  final status = response?.statusCode;
  if (response == null || status == null) {
    return _withoutResponse(error.type);
  }
  final code = _stringField(response.data, 'code');
  if (status == 401) {
    return AuthenticationFailure('Invalid credentials', code);
  }
  if (status == 403) {
    return AuthenticationFailure('Forbidden', code);
  }
  if (status == 429) {
    return _rateLimited(response, code);
  }
  if (status >= 500) {
    return ServerFailure('Server temporarily unavailable', code);
  }
  final detail = _stringField(response.data, 'detail');
  return ValidationFailure(detail ?? _fallbackText(status), code);
}

Failure _withoutResponse(DioExceptionType type) => switch (type) {
  DioExceptionType.receiveTimeout ||
  DioExceptionType.sendTimeout => const ServerFailure('Server timeout'),
  _ => const NetworkFailure('Unable to reach the server'),
};

RateLimitedFailure _rateLimited(Response<Object?> response, String? code) {
  final detail =
      _stringField(response.data, 'detail') ?? 'Too many attempts, try later';
  final retryAfter = _retryAfter(response.headers.value('retry-after'));
  final message = retryAfter == null
      ? detail
      : '$detail · Retry in ${_minutes(retryAfter)} min';
  return RateLimitedFailure(message, retryAfter: retryAfter, code: code);
}

/// Only the delta-seconds form is honoured (what the backend sends).
Duration? _retryAfter(String? raw) {
  final seconds = raw == null ? null : int.tryParse(raw.trim());
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

int _minutes(Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil();
  return minutes < 1 ? 1 : minutes;
}

String _fallbackText(int status) => switch (status) {
  404 => 'Not found',
  409 => 'Conflict',
  413 => 'Payload too large',
  422 => 'Invalid request',
  _ => 'Request rejected',
};

String? _stringField(Object? data, String key) {
  if (data is Map) {
    final value = data[key];
    return value is String ? value : null;
  }
  return null;
}
