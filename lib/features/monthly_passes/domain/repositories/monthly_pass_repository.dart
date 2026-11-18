import '../commands/create_monthly_pass_command.dart';
import '../commands/update_monthly_pass_command.dart';
import '../entities/monthly_pass.dart';
import '../entities/monthly_pass_payment.dart';
import '../entities/pass_renewal_offer_summary.dart';

abstract class MonthlyPassRepository {
  Future<List<MonthlyPass>> list({int? vehicleId});

  Future<MonthlyPass> create(CreateMonthlyPassCommand command);

  Future<MonthlyPass> update(UpdateMonthlyPassCommand command);

  Future<void> delete(int id);

  Future<List<MonthlyPassPayment>> pendingPayments();

  Future<MonthlyPassPayment> registerPayment(int id, String method);

  /// Renewal offers of the active lot, keyed by pass. Online only: offline it
  /// returns an empty list (the chips simply do not render).
  Future<List<PassRenewalOfferSummary>> renewalOffers();

  /// Queues the renewal link for [passId]; returns whether WhatsApp accepted
  /// it into the queue. Never queued offline.
  Future<bool> sendRenewalLink(int passId);
}
