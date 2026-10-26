import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';

abstract class CustomerMessageRemoteDataSource {
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    required String language,
  });
}

class SupabaseCustomerMessageRemoteDataSource
    implements CustomerMessageRemoteDataSource {
  SupabaseCustomerMessageRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> enqueueWhatsapp({
    required String phone,
    required String template,
    required List<String> params,
    required String language,
  }) async {
    try {
      await _client.rpc(
        'enqueue_whatsapp_message',
        params: {
          'p_to_phone': phone,
          'p_template': template,
          'p_params': params,
          'p_language': language,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
