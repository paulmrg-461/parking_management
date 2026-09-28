import 'package:dio/dio.dart';

import 'session_reader.dart';

/// Adds `Authorization: Bearer <token>` to every same-origin request and
/// reports an expired session (401 on an authenticated request) through
/// [_onUnauthorized] so the app can log out.
///
/// Requests flagged with [skipAuthKey] in `Options.extra` (the login call)
/// never carry a token and never trigger the logout callback.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._session, this._onUnauthorized);

  static const skipAuthKey = 'skipAuth';
  static const _header = 'Authorization';

  final SessionReader _session;
  final void Function() _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_skips(options) && _isSameOrigin(options)) {
      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        options.headers[_header] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isExpiredSession(err)) {
      _onUnauthorized();
    }
    handler.next(err);
  }

  Future<String?> _readToken() async {
    try {
      return await _session.currentToken();
    } on Object {
      return null;
    }
  }

  bool _skips(RequestOptions options) => options.extra[skipAuthKey] == true;

  bool _isSameOrigin(RequestOptions options) {
    if (options.baseUrl.isEmpty) {
      return !options.uri.hasAuthority;
    }
    return options.uri.origin == Uri.parse(options.baseUrl).origin;
  }

  bool _isExpiredSession(DioException err) =>
      err.response?.statusCode == 401 &&
      !_skips(err.requestOptions) &&
      err.requestOptions.headers.containsKey(_header);
}
