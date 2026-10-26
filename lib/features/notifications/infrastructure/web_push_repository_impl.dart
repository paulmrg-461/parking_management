import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/web_push_subscription.dart';
import '../domain/repositories/web_push_repository.dart';

class SupabaseWebPushRepository implements WebPushRepository {
  SupabaseWebPushRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> save(WebPushSubscription subscription) async {
    try {
      await _client.rpc(
        'save_web_push_subscription',
        params: {
          'p_endpoint': subscription.endpoint,
          'p_p256dh': subscription.p256dh,
          'p_auth': subscription.auth,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> remove(String endpoint) async {
    try {
      await _client.rpc(
        'delete_web_push_subscription',
        params: {'p_endpoint': endpoint},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
