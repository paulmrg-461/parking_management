import '../../../core/pagination/paged_result.dart';
import '../domain/entities/fiscal_customer.dart';
import '../domain/entities/fiscal_document.dart';
import '../domain/entities/fiscal_resolution.dart';
import '../domain/entities/fiscal_settings.dart';
import '../domain/repositories/invoicing_repository.dart';
import 'invoicing_remote_data_source.dart';

class InvoicingRepositoryImpl implements InvoicingRepository {
  InvoicingRepositoryImpl(this._remote);

  final InvoicingRemoteDataSource _remote;

  @override
  Future<FiscalConfig> config() => _remote.config();

  @override
  Future<FiscalSettings> settings() => _remote.settings();

  @override
  Future<FiscalSettings> saveSettings(FiscalSettings settings) =>
      _remote.saveSettings(settings);

  @override
  Future<List<FiscalResolution>> resolutions() => _remote.resolutions();

  @override
  Future<FiscalResolution> saveResolution(FiscalResolution resolution) =>
      _remote.saveResolution(resolution);

  @override
  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit = 50,
    int offset = 0,
  }) => _remote.documents(status: status, limit: limit, offset: offset);

  @override
  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer}) =>
      _remote.retry(id, customer: customer);

  @override
  Future<FiscalDocSummary> requestCreditNote(int id, String reason) =>
      _remote.requestCreditNote(id, reason);

  @override
  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  }) => _remote.issueForSession(sessionId, customer: customer);

  @override
  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  }) => _remote.issueForPassPayment(paymentId, customer: customer);

  @override
  Future<FiscalDocSummary?> documentForSession(int sessionId) =>
      _remote.documentForSession(sessionId);
}
