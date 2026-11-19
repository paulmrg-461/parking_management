import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/connectivity_cubit.dart';
import 'package:parking_management/core/network/connectivity_service.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/invoicing/application/invoicing_cubit.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_document.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_resolution.dart';
import 'package:parking_management/features/invoicing/domain/entities/fiscal_settings.dart';
import 'package:parking_management/features/invoicing/presentation/invoicing_page.dart';

import '../../../helpers/fake_invoicing_repository.dart';
import '../../../helpers/test_app.dart';

class _SlowRepository extends FakeInvoicingRepository {
  final gate = Completer<FiscalSettings>();
  final resolutionGate = Completer<List<FiscalResolution>>();

  @override
  Future<FiscalSettings> settings() => gate.future;

  @override
  Future<List<FiscalResolution>> resolutions() => resolutionGate.future;
}

class _OfflineService implements ConnectivityService {
  @override
  Future<bool> isOnline() async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}

FiscalDocument document({
  int id = 7,
  FiscalStatus status = FiscalStatus.pending,
  bool voided = false,
}) => FiscalDocument(
  id: id,
  docType: FiscalDocType.pos,
  fullNumber: 'SETP$id',
  status: status,
  total: 11900,
  taxAmount: 1900,
  voided: voided,
);

Future<InvoicingCubit> _pump(
  WidgetTester tester,
  FakeInvoicingRepository repository, {
  ConnectivityCubit? connectivity,
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = InvoicingCubit(repository);
  addTearDown(cubit.close);
  Widget page = BlocProvider<InvoicingCubit>.value(
    value: cubit,
    child: const InvoicingPage(),
  );
  if (connectivity != null) {
    page = BlocProvider<ConnectivityCubit>.value(
      value: connectivity,
      child: page,
    );
  }
  await tester.pumpWidget(testApp(page));
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('skeleton while loading', (tester) async {
    final repository = _SlowRepository();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = InvoicingCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider<InvoicingCubit>.value(
          value: cubit,
          child: const InvoicingPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
    repository.gate.complete(const FiscalSettings());
    repository.resolutionGate.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('empty state shows the call to action', (tester) async {
    await _pump(
      tester,
      FakeInvoicingRepository(documents: const <FiscalDocument>[]),
    );

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byKey(const Key('invoicing_empty_cta')), findsOneWidget);
  });

  testWidgets('error state shows Retry', (tester) async {
    await _pump(
      tester,
      FakeInvoicingRepository()..loadError = const NetworkFailure('offline'),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('status chips are rendered for each document', (tester) async {
    await _pump(
      tester,
      FakeInvoicingRepository(
        documents: [
          document(id: 1, status: FiscalStatus.pending),
          document(id: 2, status: FiscalStatus.accepted),
          document(id: 3, status: FiscalStatus.rejected),
        ],
      ),
    );

    expect(find.text('Pendiente'), findsWidgets);
    expect(find.text('Aceptado'), findsWidgets);
    expect(find.text('Rechazado'), findsWidgets);
  });

  testWidgets('retry and credit note actions only for allowed states', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeInvoicingRepository(
        documents: [
          document(id: 1, status: FiscalStatus.pending),
          document(id: 2, status: FiscalStatus.rejected),
          document(id: 3, status: FiscalStatus.accepted),
        ],
      ),
    );

    expect(find.byKey(const Key('invoice_retry_1')), findsNothing);
    expect(find.byKey(const Key('invoice_credit_1')), findsNothing);
    expect(find.byKey(const Key('invoice_retry_2')), findsOneWidget);
    expect(find.byKey(const Key('invoice_credit_2')), findsNothing);
    expect(find.byKey(const Key('invoice_credit_3')), findsOneWidget);
  });

  testWidgets('retry calls the cubit', (tester) async {
    final repository = FakeInvoicingRepository(
      documents: [document(id: 2, status: FiscalStatus.rejected)],
    );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('invoice_retry_2')));
    await tester.pumpAndSettle();

    expect(repository.retryCalls, 1);
  });

  testWidgets('a credit note requires a reason', (tester) async {
    final repository = FakeInvoicingRepository(
      documents: [document(id: 3, status: FiscalStatus.accepted)],
    );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('invoice_credit_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoice_credit_save')));
    await tester.pumpAndSettle();

    expect(repository.creditCalls, 0);
    expect(find.byKey(const Key('invoice_credit_dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('invoice_credit_reason')),
      'Cliente equivocado',
    );
    await tester.tap(find.byKey(const Key('invoice_credit_save')));
    await tester.pumpAndSettle();

    expect(repository.creditCalls, 1);
    expect(repository.lastCreditReason, 'Cliente equivocado');
  });

  testWidgets('the program form saves the issuer data', (tester) async {
    final repository = FakeInvoicingRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byKey(const Key('invoicing_nit')), '900777111');
    await tester.tap(find.byKey(const Key('invoicing_save_settings')));
    await tester.pumpAndSettle();

    expect(repository.saveSettingsCalls, 1);
    expect(repository.lastSavedSettings?.issuerNit, '900777111');
  });

  testWidgets('offline shows the online-only notice', (tester) async {
    final connectivity = ConnectivityCubit(_OfflineService());
    addTearDown(connectivity.close);
    await connectivity.start();
    await _pump(
      tester,
      FakeInvoicingRepository(),
      connectivity: connectivity,
    );

    expect(find.byKey(const Key('invoicing_offline')), findsOneWidget);
    expect(find.text('Requiere conexión'), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    await _pump(tester, FakeInvoicingRepository());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('renders at 400 px without overflow', (tester) async {
    await _pump(
      tester,
      FakeInvoicingRepository(),
      size: const Size(400, 900),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a resolution from the dialog', (tester) async {
    final repository = FakeInvoicingRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('invoicing_resolution_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fiscal_resolution_save')));
    await tester.pumpAndSettle();
    expect(repository.saveResolutionCalls, 0);
    expect(find.byKey(const Key('fiscal_resolution_dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fiscal_resolution_number')),
      '18760000009',
    );
    await tester.enterText(
      find.byKey(const Key('fiscal_resolution_prefix')),
      'SETQ',
    );
    await tester.tap(find.byKey(const Key('fiscal_resolution_save')));
    await tester.pumpAndSettle();

    expect(repository.saveResolutionCalls, 1);
    expect(
      repository.resolutionRows.last.resolutionNumber,
      '18760000009',
    );
  });

  testWidgets('the filter asks the repository and shows the filter', (
    tester,
  ) async {
    final repository = FakeInvoicingRepository(
      documents: [
        document(id: 1, status: FiscalStatus.pending),
        document(id: 2, status: FiscalStatus.accepted),
      ],
    );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('invoicing_filter_accepted')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fiscal_document_2')), findsOneWidget);
    expect(find.byKey(const Key('fiscal_document_1')), findsNothing);
  });

  testWidgets('retry reloads after a load failure', (tester) async {
    final repository = FakeInvoicingRepository()
      ..loadError = const NetworkFailure('offline');
    await _pump(tester, repository);

    expect(find.byType(ErrorState), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invoicing_settings')), findsOneWidget);
  });

  testWidgets('load more appends the next page', (tester) async {
    final repository = FakeInvoicingRepository(
      documents: [document(id: 1)],
      total: 3,
    );
    await _pump(tester, repository);

    expect(find.byKey(const Key('invoicing_load_more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoicing_load_more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fiscal_document_1')), findsWidgets);
  });

  testWidgets('an out-of-range tax rate shows an error', (tester) async {
    final repository = FakeInvoicingRepository();
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('invoicing_tax_rate')),
      '20000',
    );
    await tester.tap(find.byKey(const Key('invoicing_save_settings')));
    await tester.pumpAndSettle();

    expect(repository.saveSettingsCalls, 0);
    expect(find.textContaining('no son válidos'), findsOneWidget);
  });
}
