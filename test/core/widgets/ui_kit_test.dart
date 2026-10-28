import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/empty_state.dart';
import 'package:parking_management/core/widgets/error_state.dart';
import 'package:parking_management/core/widgets/filter_bar.dart';
import 'package:parking_management/core/widgets/metric_card.dart';
import 'package:parking_management/core/widgets/section_header.dart';
import 'package:parking_management/core/widgets/skeleton.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('Success: the empty state shows title, message and CTA', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      testApp(
        EmptyState(
          title: 'Sin movimientos',
          message: 'Registra la primera entrada',
          icon: Icons.receipt_long_outlined,
          action: FilledButton(
            onPressed: () => tapped++,
            child: const Text('Registrar'),
          ),
        ),
      ),
    );

    expect(find.text('Sin movimientos'), findsOneWidget);
    expect(find.text('Registra la primera entrada'), findsOneWidget);

    await tester.tap(find.text('Registrar'));
    expect(tapped, 1);
  });

  testWidgets('Failure: the error state retries the failed load', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      testApp(
        ErrorState(message: 'Sin conexión', onRetry: () => retries++),
      ),
    );

    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });

  testWidgets('Success: a metric card is tappable and announces its value', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Center(
          child: SizedBox(
            width: 320,
            child: MetricCard(
              label: 'Ocupación',
              value: '42%',
              caption: '12 de 28 espacios',
              icon: Icons.local_parking,
              tone: MetricTone.primary,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ocupación'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('12 de 28 espacios'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ocupación: 42%. 12 de 28 espacios'),
      findsOneWidget,
    );

    await tester.tap(find.text('42%'));
    expect(taps, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('Success: the section header shows its action', (tester) async {
    await tester.pumpWidget(
      testApp(
        SectionHeader(
          icon: Icons.timeline,
          title: 'Movimientos',
          subtitle: 'Últimos 30 días',
          action: TextButton(onPressed: () {}, child: const Text('Ver todo')),
        ),
      ),
    );

    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Últimos 30 días'), findsOneWidget);
    expect(find.text('Ver todo'), findsOneWidget);
  });

  testWidgets('Success: the filter bar summarizes and clears filters', (
    tester,
  ) async {
    var cleared = 0;
    await tester.pumpWidget(
      testApp(
        FilterBar(
          summary: '3 registros',
          onClear: () => cleared++,
          clearLabel: 'Limpiar filtros',
          children: const [Text('Placa')],
        ),
      ),
    );

    expect(find.text('3 registros'), findsOneWidget);
    expect(find.text('Placa'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    expect(cleared, 1);
  });

  testWidgets('Security: skeletons are announced as loading placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(const SkeletonCardList(itemCount: 2)));

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });
}
