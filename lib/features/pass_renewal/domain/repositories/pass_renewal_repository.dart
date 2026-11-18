import '../entities/pass_renewal_checkout.dart';
import '../entities/pass_renewal_offer.dart';

/// Port for the public renewal page. Everything needs the network: nothing is
/// queued offline.
abstract class PassRenewalRepository {
  /// `null` when the token is unknown (the page shows the unavailable state).
  Future<PassRenewalOffer?> load(String token);

  Future<PassRenewalCheckout> startPayment(String token);
}
