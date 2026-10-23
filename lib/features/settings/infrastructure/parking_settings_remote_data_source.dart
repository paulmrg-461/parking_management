import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/parking_settings.dart';
import 'models/parking_settings_dto.dart';

abstract class ParkingSettingsRemoteDataSource {
  Future<ParkingSettings> fetch();

  Future<ParkingSettings> patch(Map<String, dynamic> fields);

  Future<ParkingSettings> uploadLogo(Uint8List bytes);

  Future<Uint8List> fetchLogo();
}

class SupabaseParkingSettingsRemoteDataSource
    implements ParkingSettingsRemoteDataSource {
  SupabaseParkingSettingsRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'parking_settings';
  static const _bucket = 'branding';
  static const _logoPath = 'logo';

  @override
  Future<ParkingSettings> fetch() async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', 1)
          .single();
      return ParkingSettingsDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingSettings> patch(Map<String, dynamic> fields) async {
    try {
      final row = await _client
          .from(_table)
          .update(fields)
          .eq('id', 1)
          .select()
          .single();
      return ParkingSettingsDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    try {
      await _client.storage.from(_bucket).uploadBinary(
        _logoPath,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentType(bytes),
          upsert: true,
        ),
      );
      final row = await _client.rpc(
        'set_branding_logo',
        params: {'p_path': _logoPath},
      );
      return ParkingSettingsDto.fromJson(
        Map<String, dynamic>.from(row as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Uint8List> fetchLogo() async {
    try {
      return await _client.storage.from(_bucket).download(_logoPath);
    } catch (_) {
      // Missing/offline logo is not fatal: the repository falls back to null.
      throw const NetworkFailure('Logo unavailable');
    }
  }

  String _contentType(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8
      ? 'image/jpeg'
      : 'image/png';
}
