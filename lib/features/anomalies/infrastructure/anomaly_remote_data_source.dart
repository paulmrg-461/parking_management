import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/anomaly_settings.dart';
import '../domain/entities/cash_anomaly.dart';

abstract class AnomalyRemoteDataSource {
  Future<AnomalyList> list({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
  });

  Future<CashAnomaly> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  });

  Future<AnomalySettings> loadSettings();

  Future<AnomalySettings> saveSettings(AnomalySettings settings);
}

class SupabaseAnomalyRemoteDataSource implements AnomalyRemoteDataSource {
  SupabaseAnomalyRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<AnomalyList> list({
    AnomalyStatus? status,
    AnomalyRule? rule,
    AnomalySeverity? severity,
  }) async {
    try {
      final result = await _client.rpc(
        'list_cash_anomalies',
        params: {
          'p_status': status?.wire,
          'p_rule': rule?.wire,
          'p_severity': severity?.wire,
          'p_limit': 100,
        },
      );
      if (result is! Map) {
        return AnomalyList.empty;
      }
      return AnomalyList.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<CashAnomaly> resolve({
    required int id,
    required AnomalyStatus status,
    String? note,
  }) async {
    try {
      final result = await _client.rpc(
        'resolve_cash_anomaly',
        params: {'p_id': id, 'p_status': status.wire, 'p_note': note},
      );
      return CashAnomaly.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<AnomalySettings> loadSettings() async {
    try {
      final result = await _client.rpc('get_anomaly_settings');
      if (result is! Map) {
        return AnomalySettings.defaults;
      }
      return AnomalySettings.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<AnomalySettings> saveSettings(AnomalySettings settings) async {
    try {
      final result = await _client.rpc(
        'set_anomaly_settings',
        params: {'p_settings': settings.toJson()},
      );
      if (result is! Map) {
        return settings;
      }
      return AnomalySettings.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
