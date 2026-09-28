import 'dart:convert';

import 'package:dio/dio.dart';

/// Captures each request and answers with the handler's [ResponseBody].
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(
  Object? body,
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

/// A [Dio] whose adapter is [adapter] (exposed for request assertions).
Dio dioWith(FakeHttpAdapter adapter) => Dio()..httpClientAdapter = adapter;
