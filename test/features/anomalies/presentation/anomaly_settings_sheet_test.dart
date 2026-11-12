import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/anomalies/application/anomalies_cubit.dart';
import 'package:parking_management/features/anomalies/presentation/widgets/anomaly_settings_sheet.dart';

import '../../../helpers/fake_anomaly_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeAnomalyRepository> _pump(
  WidgetTester tester, {
  FakeAnomalyRepository? repository,
}) async {
  final fake = repository ?? FakeAnomalyRepository();
  final cubit = AnomaliesCubit(fake);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: AnomalySettingsSheet()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('Success: loads and saves the thresholds', (tester) async {
    final repository = await _pump(tester);

    expect(find.text('Umbrales'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('anomaly-settings-window_days')),
      '21',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('anomaly-settings-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anomaly-settings-save')));
    await tester.pumpAndSettle();

    expect(repository.saved.single.windowDays, 21);
  });

  testWidgets('Success: disabling a rule travels in the payload', (
    tester,
  ) async {
    final repository = await _pump(tester);

    await tester.tap(
      find.byKey(const Key('anomaly-settings-rule-zero_charge')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('anomaly-settings-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anomaly-settings-save')));
    await tester.pumpAndSettle();

    expect(
      repository.saved.single.disabledRules.map((rule) => rule.wire),
      contains('zero_charge'),
    );
  });

  testWidgets('Failure: a server error shows inline and keeps the sheet', (
    tester,
  ) async {
    final repository = FakeAnomalyRepository()
      ..settingsError = const ValidationFailure(
        'InvalidAnomalySettingError',
        'InvalidAnomalySettingError',
      );
    await _pump(tester, repository: repository);

    expect(find.text('Revisa los valores de los umbrales'), findsOneWidget);
    expect(find.byKey(const Key('anomaly-settings-save')), findsNothing);
  });
}
