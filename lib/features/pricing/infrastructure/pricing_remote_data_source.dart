import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/pricing_impact_report.dart';
import '../domain/entities/pricing_rule.dart';
import '../domain/entities/pricing_settings.dart';
import '../domain/entities/pricing_simulation.dart';

abstract class PricingRemoteDataSource {
  Future<PricingSettings> loadSettings();
  Future<PricingSettings> saveSettings(PricingSettings settings);
  Future<List<PricingRule>> listRules();
  Future<PricingRule> saveRule(PricingRuleDraft draft);
  Future<void> deleteRule(int id);
  Future<PricingSimulation> simulate({
    required int days,
    List<PricingRuleDraft>? candidates,
  });
  Future<PricingImpactReport> impact({
    required DateTime from,
    required DateTime to,
  });
}

class SupabasePricingRemoteDataSource implements PricingRemoteDataSource {
  SupabasePricingRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<PricingSettings> loadSettings() async {
    try {
      final result = await _client.rpc('get_pricing_settings');
      return PricingSettings.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PricingSettings> saveSettings(PricingSettings settings) async {
    try {
      final result = await _client.rpc(
        'set_pricing_settings',
        params: {
          'p_enabled': settings.enabled,
          'p_floor_bps': settings.floorBps,
          'p_ceiling_bps': settings.ceilingBps,
          'p_round_to': settings.roundTo,
        },
      );
      return PricingSettings.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<PricingRule>> listRules() async {
    try {
      final result = await _client.rpc('list_pricing_rules');
      return [
        for (final item in (result as List? ?? const []))
          if (item is Map)
            PricingRule.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PricingRule> saveRule(PricingRuleDraft draft) async {
    try {
      final result = await _client.rpc(
        'save_pricing_rule',
        params: draft.toParams(),
      );
      return PricingRule.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> deleteRule(int id) async {
    try {
      await _client.rpc('delete_pricing_rule', params: {'p_id': id});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PricingSimulation> simulate({
    required int days,
    List<PricingRuleDraft>? candidates,
  }) async {
    try {
      final result = await _client.rpc(
        'pricing_simulate',
        params: {
          'p_days': days,
          'p_rules': candidates == null
              ? null
              : [
                  for (final draft in candidates)
                    {
                      'name': draft.name,
                      'priority': draft.priority,
                      'group': draft.group,
                      'min_occupancy': draft.minOccupancyPct,
                      'max_occupancy': draft.maxOccupancyPct,
                      'weekdays': draft.weekdays,
                      'from_time': draft.fromMinute == null
                          ? null
                          : wireFromMinutes(draft.fromMinute),
                      'to_time': draft.toMinute == null
                          ? null
                          : wireFromMinutes(draft.toMinute),
                      'multiplier_bps': draft.multiplierBps,
                      'surcharge_amount': draft.surchargeAmount,
                    },
                ],
        },
      );
      return PricingSimulation.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<PricingImpactReport> impact({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _client.rpc(
        'report_pricing_impact',
        params: {'p_start_date': _date(from), 'p_end_date': _date(to)},
      );
      return PricingImpactReport.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static String _date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
