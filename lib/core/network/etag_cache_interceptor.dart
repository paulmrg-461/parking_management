import 'package:dio/dio.dart';

const _etagHeader = 'etag';
const _ifNoneMatchHeader = 'If-None-Match';
const _replayedHeader = 'idempotent-replayed';

/// `true` when the backend answered from its idempotency store (a retried
/// POST that had already succeeded). The body is the original result, so
/// callers treat it exactly like a fresh success.
bool isIdempotentReplay(Response<Object?> response) =>
    response.headers.value(_replayedHeader)?.toLowerCase() == 'true';

/// In-memory conditional GET cache for rarely-changing reference data
/// (categories, tariffs). Stores the body + `ETag` of each 200, sends
/// `If-None-Match` next time and turns a `304 Not Modified` back into a 200
/// with the cached body, so data sources never see the 304.
///
/// Only GETs to [cacheablePaths] (exact path, any query) are touched.
class EtagCacheInterceptor extends Interceptor {
  EtagCacheInterceptor({required this.cacheablePaths});

  final Set<String> cacheablePaths;
  final Map<String, _Entry> _cache = {};

  /// Drops every cached body (e.g. on logout).
  void clear() => _cache.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final entry = _cacheable(options) ? _cache[_key(options)] : null;
    if (entry != null) {
      options.headers[_ifNoneMatchHeader] = entry.etag;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final etag = response.headers.value(_etagHeader);
    if (_cacheable(response.requestOptions) &&
        response.statusCode == 200 &&
        etag != null) {
      _cache[_key(response.requestOptions)] = _Entry(etag, response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final entry = _cacheable(options) ? _cache[_key(options)] : null;
    if (err.response?.statusCode == 304 && entry != null) {
      handler.resolve(_fromCache(err.response!, entry));
      return;
    }
    handler.next(err);
  }

  Response<dynamic> _fromCache(Response<dynamic> notModified, _Entry entry) =>
      Response<dynamic>(
        requestOptions: notModified.requestOptions,
        data: entry.body,
        statusCode: 200,
        headers: notModified.headers,
        extra: {'fromEtagCache': true},
      );

  bool _cacheable(RequestOptions options) =>
      options.method.toUpperCase() == 'GET' &&
      cacheablePaths.contains(options.uri.path);

  String _key(RequestOptions options) => options.uri.toString();
}

class _Entry {
  const _Entry(this.etag, this.body);

  final String etag;
  final Object? body;
}
