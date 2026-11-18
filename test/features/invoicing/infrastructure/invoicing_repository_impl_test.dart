import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_resolution.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';
import 'package:parking_management/features/invoicing/infrastructure/invoicing_remote_data_source.dart';
import 'package:parking_management/features/invoicing/infrastructure/invoicing_repository_impl.dart';

import '../../../helpers/fake_invoicing_repository.dart';

void main() {
  test('Success: every call delegates to the data source', () async {
    final repository = FakeInvoicingRepository();
    final impl = InvoicingRepositoryImpl(_Remote(repository));

    final settings = await impl.settings();
    expect(settings.mode, FiscalMode.onRequest);
    expect((await impl.resolutions()).single.prefix, 'SETP');
    expect((await impl.documents()).items, isNotEmpty);
    expect((await impl.retry(7)).fullNumber, 'SETP7');
    expect((await impl.issueForSession(3)).documentId, 7);
  });
}

class _Remote implements InvoicingRemoteDataSource {
  _Remote(this.fake);
  final FakeInvoicingRepository fake;

  @override
  Future<FiscalConfig> config() => fake.config();
  @override
  Future<FiscalSettings> settings() => fake.settings();
  @override
  Future<FiscalSettings> saveSettings(FiscalSettings settings) =>
      fake.saveSettings(settings);
  @override
  Future<List<FiscalResolution>> resolutions() => fake.resolutions();
  @override
  Future<FiscalResolution> saveResolution(FiscalResolution resolution) =>
      fake.saveResolution(resolution);
  @override
  Future<PagedResult<FiscalDocument>> documents({
    FiscalStatus? status,
    int limit = 50,
    int offset = 0,
  }) => fake.documents(status: status, limit: limit, offset: offset);
  @override
  Future<FiscalDocSummary> retry(int id, {FiscalCustomer? customer}) =>
      fake.retry(id, customer: customer);
  @override
  Future<FiscalDocSummary> requestCreditNote(int id, String reason) =>
      fake.requestCreditNote(id, reason);
  @override
  Future<FiscalDocSummary> issueForSession(
    int sessionId, {
    FiscalCustomer? customer,
  }) => fake.issueForSession(sessionId, customer: customer);
  @override
  Future<FiscalDocSummary> issueForPassPayment(
    int paymentId, {
    FiscalCustomer? customer,
  }) => fake.issueForPassPayment(paymentId, customer: customer);
  @override
  Future<FiscalDocSummary?> documentForSession(int sessionId) =>
      fake.documentForSession(sessionId);
}
