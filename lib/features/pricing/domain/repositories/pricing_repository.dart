import '../entities/pricing_impact_report.dart';
import '../entities/pricing_rule.dart';
import '../entities/pricing_settings.dart';
import '../entities/pricing_simulation.dart';

/// Admin port: rules, settings, simulation and the impact report. Online only.
abstract class PricingRepository {
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
