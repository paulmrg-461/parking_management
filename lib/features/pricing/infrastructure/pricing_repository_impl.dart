import '../domain/entities/pricing_impact_report.dart';
import '../domain/entities/pricing_rule.dart';
import '../domain/entities/pricing_settings.dart';
import '../domain/entities/pricing_simulation.dart';
import '../domain/repositories/price_quote_repository.dart';
import '../domain/repositories/pricing_repository.dart';
import '../domain/entities/price_quote.dart';
import '../domain/entities/session_price_lock.dart';
import 'price_quote_remote_data_source.dart';
import 'pricing_remote_data_source.dart';

class PricingRepositoryImpl implements PricingRepository {
  PricingRepositoryImpl(this._remote);

  final PricingRemoteDataSource _remote;

  @override
  Future<PricingSettings> loadSettings() => _remote.loadSettings();

  @override
  Future<PricingSettings> saveSettings(PricingSettings settings) =>
      _remote.saveSettings(settings);

  @override
  Future<List<PricingRule>> listRules() => _remote.listRules();

  @override
  Future<PricingRule> saveRule(PricingRuleDraft draft) =>
      _remote.saveRule(draft);

  @override
  Future<void> deleteRule(int id) => _remote.deleteRule(id);

  @override
  Future<PricingSimulation> simulate({
    required int days,
    List<PricingRuleDraft>? candidates,
  }) => _remote.simulate(days: days, candidates: candidates);

  @override
  Future<PricingImpactReport> impact({
    required DateTime from,
    required DateTime to,
  }) => _remote.impact(from: from, to: to);
}

class PriceQuoteRepositoryImpl implements PriceQuoteRepository {
  PriceQuoteRepositoryImpl(this._remote);

  final PriceQuoteRemoteDataSource _remote;

  @override
  Future<PriceQuote> quote(int categoryId) => _remote.quote(categoryId);

  @override
  Future<SessionPriceLock?> sessionLock(int sessionId) =>
      _remote.sessionLock(sessionId);

  @override
  Future<SessionPriceLock?> reservationLock({
    required int lotId,
    required int reservationId,
    required String phone,
  }) => _remote.reservationLock(
    lotId: lotId,
    reservationId: reservationId,
    phone: phone,
  );
}
