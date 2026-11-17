import '../entities/payment_intent.dart';
import '../entities/payment_status.dart';

/// Port for the payment functions. Nothing here is queued offline: paying
/// needs the network by definition.
abstract class OnlinePaymentRepository {
  /// Asks the server to price the session and returns the gateway checkout.
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  });

  /// Polls the intent; `null` when the reference or the plate does not match.
  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  });
}
