import '../entities/price_quote.dart';
import '../entities/session_price_lock.dart';

/// Operator + customer reads: the price now and the stored lock.
abstract class PriceQuoteRepository {
  Future<PriceQuote> quote(int categoryId);

  Future<SessionPriceLock?> sessionLock(int sessionId);

  Future<SessionPriceLock?> reservationLock({
    required int lotId,
    required int reservationId,
    required String phone,
  });
}
