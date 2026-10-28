import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/lot/lot_session.dart';
import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/parking_settings.dart';
import 'models/parking_settings_dto.dart';

abstract class ParkingSettingsRemoteDataSource {
  Future<ParkingSettings> fetch();

  Future<ParkingSettings> patch(Map<String, dynamic> fields);

  Future<ParkingSettings> uploadLogo(Uint8List bytes);

  Future<Uint8List> fetchLogo();

  Future<String> resetLegalPolicy();
}

class SupabaseParkingSettingsRemoteDataSource
    implements ParkingSettingsRemoteDataSource {
  SupabaseParkingSettingsRemoteDataSource(this._client, this._lots);

  final SupabaseClient _client;
  final LotSession _lots;

  static const _table = 'parking_settings';
  static const _bucket = 'branding';

  @override
  Future<ParkingSettings> fetch() async {
    try {
      // RLS returns only the active lot's row; `order` keeps it deterministic
      // for the single-lot fallback.
      final rows = await _client.from(_table).select().order('id').limit(1);
      if (rows.isEmpty) {
        throw StateError('Parking settings missing');
      }
      final row = rows.first;
      return ParkingSettingsDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingSettings> patch(Map<String, dynamic> fields) async {
    try {
      final lotId = _lots.activeLotId;
      if (lotId == null) {
        throw StateError('Select a parking lot first');
      }
      final row = await _client
          .from(_table)
          .update(fields)
          .eq('lot_id', lotId)
          .select()
          .single();
      return ParkingSettingsDto.fromJson(row).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  int get _lotId {
    final lotId = _lots.activeLotId;
    if (lotId == null) {
      throw StateError('Select a parking lot first');
    }
    return lotId;
  }

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    try {
      final path = logoPathForLot(_lotId);
      await _client.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentType(bytes),
          upsert: true,
        ),
      );
      final row = await _client.rpc(
        'set_branding_logo',
        params: {'p_path': path},
      );
      return ParkingSettingsDto.fromJson(
        Map<String, dynamic>.from(row as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<String> resetLegalPolicy() async {
    try {
      final result = await _client.rpc('reset_legal_policy');
      return result as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Uint8List> fetchLogo() async {
    try {
      return await _client.storage.from(_bucket).download(
        logoPathForLot(_lotId),
      );
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

/// One logo object per lot, so uploading a site's logo never overwrites the
/// other site's branding.
String logoPathForLot(int lotId) => 'logo_$lotId';
