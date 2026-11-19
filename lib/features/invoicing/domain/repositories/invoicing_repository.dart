import '../../../../core/pagination/paged_result.dart';
import '../entities/fiscal_customer.dart';
import '../entities/fiscal_document.dart';
import '../entities/fiscal_resolution.dart';
import '../entities/fiscal_settings.dart';

/// Fiscal port. Every method is online only: nothing is queued in the outbox.
abstract class InvoicingRepository {
  Future<FiscalConfig> config();

  Future<FiscalSettings> settings();

  Future<FiscalSettings> saveSettings(FiscalSettings settings);

  Future<List<FiscalResolution>> resolutions();

  Future<FiscalResolution> saveResolution(FiscalResolution resolution);

  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit = 50,
    int offset = 0,
  });

  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer});

  Future<FiscalDocSummary> requestCreditNote(int id, String reason);

  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  });

  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  });

  Future<FiscalDocSummary?> documentForSession(int sessionId);
}
