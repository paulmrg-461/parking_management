import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/invoicing/application/issue_fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_customer.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';

import '../../../helpers/fake_invoicing_repository.dart';

const _onRequest = FiscalConfig(mode: FiscalMode.onRequest);

void main() {
  test('Success: returns the summary', () async {
    final repository = FakeInvoicingRepository();
    final useCase = IssueFiscalDocument(repository);

    final summary = await useCase.forSession(3, config: _onRequest);

    expect(summary?.fullNumber, 'SETP7');
    expect(repository.issueCalls, 1);
  });

  test('Failure: swallows a repository failure and returns null', () async {
    final repository = FakeInvoicingRepository()..writeError =
        const ValidationFailure('FiscalNotEnabledError', 'FiscalNotEnabledError');
    final useCase = IssueFiscalDocument(repository);

    expect(await useCase.forSession(3, config: _onRequest), isNull);
  });

  test('Success: does nothing when the mode is off', () async {
    final repository = FakeInvoicingRepository();
    final useCase = IssueFiscalDocument(repository);

    expect(
      await useCase.forSession(
        3,
        config: const FiscalConfig(mode: FiscalMode.off),
      ),
      isNull,
    );
    expect(repository.issueCalls, 0);
  });

  test('Success: does nothing when offline', () async {
    final repository = FakeInvoicingRepository();
    final useCase = IssueFiscalDocument(repository);

    expect(
      await useCase.forSession(3, config: _onRequest, online: false),
      isNull,
    );
    expect(repository.issueCalls, 0);
  });

  test('Failure: an invalid customer is not sent', () async {
    final repository = FakeInvoicingRepository();
    final useCase = IssueFiscalDocument(repository);

    expect(
      await useCase.forSession(
        3,
        config: _onRequest,
        customer: const FiscalCustomer(
          documentType: FiscalIdType.cc,
          documentNumber: '1',
          name: 'A',
        ),
      ),
      isNull,
    );
    expect(repository.issueCalls, 0);
  });

  test('Success: a pass payment issues through the same guard', () async {
    final repository = FakeInvoicingRepository();
    final useCase = IssueFiscalDocument(repository);

    final summary = await useCase.forPassPayment(9, config: _onRequest);

    expect(summary, isNotNull);
    expect(repository.issueCalls, 1);
  });
}
