import '../../../../core/fare/fare_quote.dart';
import '../entities/merchant.dart';
import '../entities/merchant_settlement.dart';

/// Admin + desk port. Online only: nothing is queued in the outbox.
abstract class MerchantRepository {
  Future<List<Merchant>> list();

  /// Active merchants of the active lot (the desk picker; operators can read).
  Future<List<Merchant>> listActive();

  Future<({Merchant merchant, MerchantCredentials? credentials})> save(
    MerchantDraft draft,
  );

  Future<MerchantCredentials> resetCredentials(
    int merchantId, {
    bool rotateToken = false,
  });

  Future<void> delete(int merchantId);

  Future<int> loadPolicy();

  Future<int> savePolicy(int maxPerSession);

  Future<FareQuote> addValidation({
    required int merchantId,
    required int sessionId,
  });

  Future<void> revokeValidation({
    required int validationId,
    required String reason,
  });

  Future<MerchantSettlement> settlement({
    required DateTime start,
    required DateTime end,
  });
}
