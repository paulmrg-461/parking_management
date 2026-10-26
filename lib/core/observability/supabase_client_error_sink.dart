import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_error_sink.dart';

/// Best-effort, silent by design: reporting must never break the app, and an
/// unauthenticated client has nowhere to report to.
class SupabaseClientErrorSink implements ClientErrorSink {
  SupabaseClientErrorSink(this._client);

  final SupabaseClient _client;

  @override
  Future<void> send({
    required String platform,
    required String message,
    String? stack,
    Map<String, Object?> context = const {},
  }) async {
    if (_client.auth.currentUser == null) {
      return;
    }
    try {
      await _client.rpc(
        'report_client_error',
        params: {
          'p_platform': platform,
          'p_message': message,
          'p_stack': ?stack,
          'p_context': context,
        },
      );
    } catch (_) {
      // A failed report is not an app error: never rethrow or loop.
    }
  }
}
