import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/network/versioned_write.dart';
import '../domain/entities/category.dart';
import 'models/category_dto.dart';

abstract class CategoryRemoteDataSource {
  Future<List<Category>> list();

  Future<Category> create(String name);

  Future<Category> update(int id, String name, {int? baseVersion});

  Future<Category> setCapacity(int id, int capacity, {int? baseVersion});

  /// Versioned partial update: sends every key in [payload] as one write.
  Future<Category> patch(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  });

  Future<void> delete(int id, {int? baseVersion});
}

class SupabaseCategoryRemoteDataSource implements CategoryRemoteDataSource {
  SupabaseCategoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'categories';

  @override
  Future<List<Category>> list() async {
    try {
      final rows = await _client.from(_table).select().order('id');
      return rows.map((row) => CategoryDto.fromJson(row).toDomain()).toList();
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
  Future<Category> update(int id, String name, {int? baseVersion}) =>
      patch(id, {'name': name}, baseVersion: baseVersion);

  @override
  Future<Category> setCapacity(int id, int capacity, {int? baseVersion}) =>
      patch(id, {'capacity': capacity}, baseVersion: baseVersion);

  @override
  Future<Category> patch(
    int id,
    Map<String, dynamic> payload, {
    int? baseVersion,
  }) async {
    try {
      final row = await updateVersioned(
        _client,
        _table,
        payload: payload,
        match: {'id': id},
        baseVersion: baseVersion,
      );
      return CategoryDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id, {int? baseVersion}) async {
    try {
      await deleteVersioned(
        _client,
        _table,
        match: {'id': id},
        baseVersion: baseVersion,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
