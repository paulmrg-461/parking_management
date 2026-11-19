import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/core/widgets/skeleton.dart';
import 'package:parking_management/features/loyalty/application/loyalty_admin_cubit.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_account.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';
import 'package:parking_management/features/loyalty/presentation/loyalty_page.dart';
import 'package:parking_management/features/loyalty/presentation/loyalty_report_csv.dart';

import '../../../helpers/fake_loyalty_repository.dart';
import '../../../helpers/test_app.dart';

class _LoadingRepository extends FakeLoyaltyRepository {
  final settingsGate = Completer<LoyaltySettings>();
  final accountsGate = Completer<List<LoyaltyAccount>>();

  @override
  Future<LoyaltySettings> loadSettings() => settingsGate.future;

  @override
  Future<List<LoyaltyAccount>> accounts({String? search}) => accountsGate.future;
}

Future<LoyaltyAdminCubit> _pump(
  WidgetTester tester,
  FakeLoyaltyRepository repository, {
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = LoyaltyAdminCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<LoyaltyAdminCubit>.value(
        value: cubit,
        child: const LoyaltyPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows skeleton while loading', (tester) async {
    final repository = _LoadingRepository();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = LoyaltyAdminCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider<LoyaltyAdminCubit>.value(
          value: cubit,
          child: const LoyaltyPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    repository.settingsGate.complete(const LoyaltySettings());
    repository.accountsGate.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('shows program form and saves', (tester) async {
    final repository = FakeLoyaltyRepository();
    await _pump(tester, repository);

    expect(find.byKey(const Key('loyalty_settings_form')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('loyalty_visits')), '6');
    await tester.tap(find.byKey(const Key('loyalty_save')));
    await tester.pumpAndSettle();

    expect(repository.settingsSaves, 1);
    expect(repository.settings.visitsRequired, 6);
    expect(find.text('Programa guardado'), findsOneWidget);
  });

  testWidgets('empty members shows enable call to action when program is off', (
    tester,
  ) async {
    final repository = FakeLoyaltyRepository(
      settings: const LoyaltySettings(),
      accounts: const <LoyaltyAccount>[],
    );
    await _pump(tester, repository);
    await _openTab(tester, 'Clientes');

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byKey(const Key('loyalty_enable_cta')), findsOneWidget);

    await tester.tap(find.byKey(const Key('loyalty_enable_cta')));
    await tester.pumpAndSettle();
    expect(repository.settings.enabled, isTrue);
  });

  testWidgets('members list shows progress', (tester) async {
    await _pump(tester, FakeLoyaltyRepository());
    await _openTab(tester, 'Clientes');

    expect(find.byKey(const Key('loyalty_member_ABC123')), findsOneWidget);
    expect(find.text('Visita 4 de 5'), findsOneWidget);
  });

  testWidgets('Failure: adjust dialog requires a reason', (tester) async {
    final repository = FakeLoyaltyRepository();
    await _pump(tester, repository);
    await _openTab(tester, 'Clientes');

    await tester.tap(find.byKey(const Key('loyalty_adjust_ABC123')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('loyalty_adjust_delta')), '1');
    await tester.tap(find.byKey(const Key('loyalty_adjust_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loyalty_adjust_dialog')), findsOneWidget);
    expect(find.textContaining('motivo de 3 a 200'), findsOneWidget);
    expect(repository.adjustCalls, 0);

    await tester.enterText(
      find.byKey(const Key('loyalty_adjust_reason')),
      'Ajuste manual',
    );
    await tester.tap(find.byKey(const Key('loyalty_adjust_save')));
    await tester.pumpAndSettle();

    expect(repository.adjustCalls, 1);
  });

  testWidgets('Failure: adjust dialog blocks submit out of range', (
    tester,
  ) async {
    final repository = FakeLoyaltyRepository();
    await _pump(tester, repository);
    await _openTab(tester, 'Clientes');

    await tester.tap(find.byKey(const Key('loyalty_adjust_ABC123')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('loyalty_adjust_delta')), '5');
    await tester.enterText(
      find.byKey(const Key('loyalty_adjust_reason')),
      'Ajuste manual',
    );
    await tester.tap(find.byKey(const Key('loyalty_adjust_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loyalty_adjust_dialog')), findsOneWidget);
    expect(find.textContaining('fuera de rango'), findsOneWidget);
    expect(repository.adjustCalls, 0);
  });

  testWidgets('report section shows figures', (tester) async {
    final repository = FakeLoyaltyRepository();
    await _pump(tester, repository);
    await _openTab(tester, 'Reporte');

    await tester.tap(find.byKey(const Key('loyalty_report_refresh')));
    await tester.pumpAndSettle();

    expect(repository.reportCalls, 1);
    expect(find.text('Visitas contadas'), findsWidgets);
    expect(find.textContaining('30'), findsWidgets);
    expect(find.textContaining('24.000'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  test('csv copy writes raw integers', () {
    final csv = loyaltyReportCsv(sampleReport());

    expect(csv.split('\n').first, 'section,label,value');
    expect(csv, contains('visits,counted,30'));
    expect(csv, contains('summary,discount_given,24000'));
    expect(csv, contains('top_plate_counted,ABC123,9'));
    expect(csv.contains(r'$'), isFalse);
  });

  testWidgets('error state has retry', (tester) async {
    await _pump(
      tester,
      FakeLoyaltyRepository()..loadError = const NetworkFailure('offline'),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('meets tap target and label guidelines', (tester) async {
    await _pump(tester, FakeLoyaltyRepository());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('renders at 400 px without overflow', (tester) async {
    await _pump(tester, FakeLoyaltyRepository(), size: const Size(400, 900));
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'Clientes');
    expect(tester.takeException(), isNull);
  });
}
