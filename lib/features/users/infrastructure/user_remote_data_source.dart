import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/infrastructure/models/user_dto.dart';

abstract class UserRemoteDataSource {
  Future<List<User>> list();

  Future<User> create(Map<String, dynamic> payload);

  Future<User> update(int id, Map<String, dynamic> payload);

  Future<User> resetPin(int id, String pin);

  Future<void> delete(int id);
}

class SupabaseUserRemoteDataSource implements UserRemoteDataSource {
  SupabaseUserRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'users';
  static const _function = 'admin-users';

  @override
  Future<List<User>> list() async {
    try {
      final rows = await _client
          .from(_table)
          .select('id, username, display_name, role, is_active')
          .order('id');
      return [for (final row in rows) UserDto.fromJson(row).toDomain()];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<User> create(Map<String, dynamic> payload) =>
      _adminAction({'action': 'create', ...payload});

  @override
  Future<User> update(int id, Map<String, dynamic> payload) =>
      _adminAction({'action': 'update', 'id': id, ...payload});

  @override
  Future<User> resetPin(int id, String pin) =>
      _adminAction({'action': 'reset_pin', 'id': id, 'pin': pin});

  @override
  Future<void> delete(int id) async {
    try {
      await _client.functions.invoke(
        _function,
        body: {'action': 'delete', 'id': id},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<User> _adminAction(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: body,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerFailure('Invalid admin-users response');
      }
      return UserDto.fromJson(Map<String, dynamic>.from(data)).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
