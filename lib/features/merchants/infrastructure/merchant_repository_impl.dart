import '../../../core/fare/fare_quote.dart';
import '../domain/entities/merchant.dart';
import '../domain/entities/merchant_settlement.dart';
import '../domain/repositories/merchant_repository.dart';
import 'merchant_remote_data_source.dart';

class MerchantRepositoryImpl implements MerchantRepository {
  MerchantRepositoryImpl(this._remote);

  final MerchantRemoteDataSource _remote;

  @override
  Future<List<Merchant>> list() => _remote.list();

  @override
  Future<List<Merchant>> listActive() => _remote.listActive();

  @override
  Future<({Merchant merchant, MerchantCredentials? credentials})> save(
    MerchantDraft draft,
  ) => _remote.save(draft);

  @override
  Future<MerchantCredentials> resetCredentials(
    int merchantId, {
    bool rotateToken = false,
  }) => _remote.resetCredentials(merchantId, rotateToken: rotateToken);

  @override
  Future<void> delete(int merchantId) => _remote.delete(merchantId);

  @override
  Future<int> loadPolicy() => _remote.loadPolicy();

  @override
  Future<int> savePolicy(int maxPerSession) => _remote.savePolicy(maxPerSession);

  @override
  Future<FareQuote> addValidation({
    required int merchantId,
    required int sessionId,
  }) => _remote.addValidation(merchantId: merchantId, sessionId: sessionId);

  @override
  Future<void> revokeValidation({
    required int validationId,
    required String reason,
  }) => _remote.revokeValidation(validationId: validationId, reason: reason);

  @override
  Future<MerchantSettlement> settlement({
    required DateTime start,
    required DateTime end,
  }) => _remote.settlement(start: start, end: end);
}
