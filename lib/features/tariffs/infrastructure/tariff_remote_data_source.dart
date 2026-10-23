import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/tariff.dart';
import 'models/tariff_dto.dart';

abstract class TariffRemoteDataSource {
  Future<List<Tariff>> list();

  Future<Tariff> create(Map<String, dynamic> payload);

  Future<Tariff> update(int id, Map<String, dynamic> payload);

  Future<void> delete(int id);
}

class SupabaseTariffRemoteDataSource implements TariffRemoteDataSource {
  SupabaseTariffRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'tariffs';

  @override
  Future<List<Tariff>> list() async {
    try {
      final rows = await _client.from(_table).select().order('id');
      return rows.map((row) => TariffDto.fromJson(row).toDomain()).toList();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Tariff> create(Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .insert(payload)
          .select()
          .single();
      return TariffDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Tariff> update(int id, Map<String, dynamic> payload) async {
    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return TariffDto.fromJson(row).toDomain();
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
