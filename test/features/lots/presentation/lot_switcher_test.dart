import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/lot/lot_context.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:parking_management/features/lots/application/lots_cubit.dart';
import 'package:parking_management/features/lots/presentation/lot_switcher.dart';

import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/fake_lots_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  Future<LotsCubit> pumpBar(
    WidgetTester tester,
    List<dynamic> lots,
  ) async {
    final cubit = LotsCubit(
      FakeLotsRepository([for (final lot in lots) lot]),
      LotContext(FakeKeyValueStore(), LotSession()),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: LotSwitcher()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('Security: a single-lot user sees no switcher', (tester) async {
    await pumpBar(tester, [sampleLot()]);

    expect(find.text('Central'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('Success: the active lot is shown and can be switched', (
    tester,
  ) async {
    final cubit = await pumpBar(tester, [
      sampleLot(),
      sampleLot(id: 2, code: 'N2', name: 'North'),
    ]);

    expect(find.text('Central'), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar de sede'), findsOneWidget);

    await tester.tap(find.text('North'));
    await tester.pumpAndSettle();

    expect((cubit.state as LotsLoaded).activeId, 2);
    expect(find.text('North'), findsOneWidget);
  });
}
