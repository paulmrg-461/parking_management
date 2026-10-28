import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/lot_profile.dart';

abstract class PolicyRemoteDataSource {
  Future<LotProfile> fetch(int lotId);
}

class SupabasePolicyRemoteDataSource implements PolicyRemoteDataSource {
  SupabasePolicyRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<LotProfile> fetch(int lotId) async {
    try {
      final result = await _client.rpc(
        'public_lot_profile',
        params: {'p_lot_id': lotId},
      );
      if (result is! Map) {
        throw const ValidationFailure(
          'Policy not available',
          'PolicyNotFoundError',
        );
      }
      return LotProfile.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
