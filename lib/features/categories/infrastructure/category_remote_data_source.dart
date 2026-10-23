import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/category.dart';
import 'models/category_dto.dart';

abstract class CategoryRemoteDataSource {
  Future<List<Category>> list();

  Future<Category> create(String name);

  Future<Category> update(int id, String name);

  Future<Category> setCapacity(int id, int capacity);

  Future<void> delete(int id);
}

class SupabaseCategoryRemoteDataSource implements CategoryRemoteDataSource {
  SupabaseCategoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'categories';

  @override
  Future<List<Category>> list() async {
    try {
      final rows = await _client.from(_table).select().order('id');
      return rows
          .map((row) => CategoryDto.fromJson(row).toDomain())
          .toList();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Category> create(String name) async {
    try {
      final row = await _client
          .from(_table)
          .insert({'name': name})
          .select()
          .single();
      return CategoryDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Category> update(int id, String name) =>
      _patch(id, {'name': name});

  @override
  Future<Category> setCapacity(int id, int capacity) =>
      _patch(id, {'capacity': capacity});

  Future<Category> _patch(int id, Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return CategoryDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
