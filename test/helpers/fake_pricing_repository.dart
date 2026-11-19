import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pricing/domain/entities/price_quote.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_impact_report.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_rule.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_settings.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_simulation.dart';
import 'package:parking_management/features/pricing/domain/entities/session_price_lock.dart';
import 'package:parking_management/features/pricing/domain/repositories/price_quote_repository.dart';
import 'package:parking_management/features/pricing/domain/repositories/pricing_repository.dart';

final sampleRule = PricingRule(
  id: 1,
  name: 'Alta ocupacion',
  group: 'car',
  minOccupancyPct: 80,
  maxOccupancyPct: 100,
  multiplierBps: 12000,
  priority: 200,
);

class FakePricingRepository implements PricingRepository {
  FakePricingRepository({
    List<PricingRule>? rules,
    this.settings = const PricingSettings(enabled: true),
    this.simulation = const PricingSimulation(
      days: 30,
      sessionsConsidered: 10,
      sessionsAffected: 4,
      baseTotal: 100000,
      simulatedTotal: 112000,
      delta: 12000,
    ),
    this.impactReport = const PricingImpactReport(),
  }) : rules = rules ?? [sampleRule];

  List<PricingRule> rules;
  PricingSettings settings;
  PricingSimulation simulation;
  PricingImpactReport impactReport;
  Failure? loadError;
  Failure? writeError;
  final List<PricingRuleDraft> saved = [];
  final List<int> deleted = [];
  int settingsSaves = 0;
  int simulationCalls = 0;
  int impactCalls = 0;
  int listCalls = 0;

  @override
  Future<PricingSettings> loadSettings() async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return settings;
  }

  @override
  Future<PricingSettings> saveSettings(PricingSettings next) async {
    _throwIfWriteFails();
    settingsSaves++;
    settings = next;
    return next;
  }

  @override
  Future<List<PricingRule>> listRules() async {
    listCalls++;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return List.of(rules);
  }

  @override
  Future<PricingRule> saveRule(PricingRuleDraft draft) async {
    _throwIfWriteFails();
    saved.add(draft);
    final rule = PricingRule(
      id: draft.id ?? 9,
      name: draft.name,
      priority: draft.priority,
      group: draft.group,
      minOccupancyPct: draft.minOccupancyPct,
      maxOccupancyPct: draft.maxOccupancyPct,
      weekdays: draft.weekdays,
      fromMinute: draft.fromMinute,
      toMinute: draft.toMinute,
      multiplierBps: draft.multiplierBps,
      surchargeAmount: draft.surchargeAmount,
      active: draft.active,
    );
    rules = [
      for (final item in rules)
        if (item.id != rule.id) item,
      rule,
    ];
    return rule;
  }

  @override
  Future<void> deleteRule(int id) async {
    _throwIfWriteFails();
    deleted.add(id);
    rules = [
      for (final item in rules)
        if (item.id != id) item,
    ];
  }

  @override
  Future<PricingSimulation> simulate({
    required int days,
    List<PricingRuleDraft>? candidates,
  }) async {
    simulationCalls++;
    _throwIfWriteFails();
    return simulation;
  }

  @override
  Future<PricingImpactReport> impact({
    required DateTime from,
    required DateTime to,
  }) async {
    impactCalls++;
    return impactReport;
  }

  void _throwIfWriteFails() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }
}

class FakePriceQuoteRepository implements PriceQuoteRepository {
  FakePriceQuoteRepository({
    this.quoteResult = const PriceQuote(
      enabled: true,
      categoryId: 1,
      hourlyBase: 3000,
      hourlyCurrent: 3600,
      tier: PriceTier.higher,
      ruleName: 'Alta ocupacion',
    ),
    this.lock,
    this.failure,
  });

  PriceQuote quoteResult;
  SessionPriceLock? lock;
  Failure? failure;
  int quoteCalls = 0;
  int lockCalls = 0;

  @override
  Future<PriceQuote> quote(int categoryId) async {
    quoteCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return quoteResult;
  }

  @override
  Future<SessionPriceLock?> sessionLock(int sessionId) async {
    lockCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return lock;
  }

  @override
  Future<SessionPriceLock?> reservationLock({
    required int lotId,
    required int reservationId,
    required String phone,
  }) async {
    lockCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return lock;
  }
}
