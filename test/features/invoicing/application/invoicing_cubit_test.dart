import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/invoicing/application/invoicing_cubit.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';

import '../../../helpers/fake_invoicing_repository.dart';

void main() {
  InvoicingLoaded loaded(InvoicingCubit cubit) =>
      cubit.state as InvoicingLoaded;

  test('Success: load emits loading then loaded', () async {
    final cubit = InvoicingCubit(FakeInvoicingRepository());
    final states = <InvoicingState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();

    expect(states.first, isA<InvoicingLoading>());
    expect(loaded(cubit).documents, hasLength(1));
    expect(loaded(cubit).settings.mode, FiscalMode.onRequest);
    expect(loaded(cubit).resolutions, isNotEmpty);
    await subscription.cancel();
    await cubit.close();
  });

  test('Success: an empty list is loaded with the empty flag', () async {
    final cubit = InvoicingCubit(
      FakeInvoicingRepository(documents: const <FiscalDocument>[]),
    );
    await cubit.load();
    expect(loaded(cubit).documents, isEmpty);
    await cubit.close();
  });

  test('Failure: a load error emits failure', () async {
    final cubit = InvoicingCubit(
      FakeInvoicingRepository()..loadError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<InvoicingFailure>());
    await cubit.close();
  });

  test('Success: filter by status keeps the filter', () async {
    final cubit = InvoicingCubit(FakeInvoicingRepository());
    await cubit.load();
    await cubit.filterBy(FiscalStatus.pending);
    expect(loaded(cubit).statusFilter, FiscalStatus.pending);

    await cubit.filterBy(null);
    expect(loaded(cubit).statusFilter, isNull);
    await cubit.close();
  });

  test('Success: paging appends and stops at the total', () async {
    final cubit = InvoicingCubit(
      FakeInvoicingRepository(documents: [sampleDocument], total: 3),
    );
    await cubit.load();
    expect(loaded(cubit).documents, hasLength(1));
    await cubit.loadMore();
    expect(loaded(cubit).documents.length, greaterThan(1));
    await cubit.close();
  });

  test('Success: save settings success and failure keep the list', () async {
    final repository = FakeInvoicingRepository();
    final cubit = InvoicingCubit(repository);
    await cubit.load();

    await cubit.saveSettings(
      const FiscalSettings(
        mode: FiscalMode.always,
        issuerNit: '900',
        issuerLegalName: 'X SAS',
        municipalityCode: '11001',
      ),
    );
    expect(loaded(cubit).settings.mode, FiscalMode.always);
    expect(loaded(cubit).submission, isA<SubmissionSucceeded>());

    repository.writeError = const ValidationFailure(
      'FiscalSettingsIncompleteError',
      'FiscalSettingsIncompleteError',
    );
    await cubit.saveSettings(const FiscalSettings(mode: FiscalMode.always));
    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(loaded(cubit).documents, hasLength(1));
    await cubit.close();
  });

  test('Success: retry refreshes the documents', () async {
    final repository = FakeInvoicingRepository();
    final cubit = InvoicingCubit(repository);
    await cubit.load();

    await cubit.retry(7);

    expect(repository.retryCalls, 1);
    expect(loaded(cubit).submission, isA<SubmissionSucceeded>());
    await cubit.close();
  });

  test('Failure: a credit note requires a reason', () async {
    final repository = FakeInvoicingRepository();
    final cubit = InvoicingCubit(repository);
    await cubit.load();

    await cubit.requestCreditNote(7, '  ');

    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(repository.creditCalls, 0);

    await cubit.requestCreditNote(7, 'Cliente equivocado');
    expect(repository.creditCalls, 1);
    await cubit.close();
  });
}
