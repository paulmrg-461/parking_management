import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/damage_comparison/application/damage_comparison_cubit.dart';
import 'package:parking_management/features/damage_comparison/domain/entities/damage_comparison.dart';
import 'package:parking_management/features/damage_comparison/presentation/damage_comparison_page.dart';

import '../../../helpers/fake_damage_repository.dart';
import '../../../helpers/test_app.dart';

Future<DamageComparisonCubit> _pump(
  WidgetTester tester,
  FakeDamageRepository repository,
) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = DamageComparisonCubit(repository, sessionId: 1);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<DamageComparisonCubit>.value(
        value: cubit,
        child: const DamageComparisonPage(sessionId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('empty shows the run action and runs', (tester) async {
    final repository = FakeDamageRepository();
    await _pump(tester, repository);

    expect(find.text('Aún no hay comparación'), findsOneWidget);
    await tester.tap(find.byKey(const Key('damage_run')));
    await tester.pumpAndSettle();
    expect(repository.runCalls, 1);
  });

  testWidgets('loaded shows the advisory banner and the verdict', (tester) async {
    await _pump(tester, FakeDamageRepository(view: sampleDamageView()));

    expect(find.text('Análisis orientativo con IA'), findsOneWidget);
    expect(find.text('Posible daño nuevo: verifica'), findsWidgets);
    expect(find.byKey(const Key('damage_finding_3')), findsOneWidget);
  });

  testWidgets('review requires a note', (tester) async {
    final repository = FakeDamageRepository(view: sampleDamageView());
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('damage_confirm_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('damage_review_save')));
    await tester.pumpAndSettle();
    expect(repository.reviewCalls, 0);

    await tester.enterText(
      find.byKey(const Key('damage_review_note')),
      'Verificado en el vehículo',
    );
    await tester.tap(find.byKey(const Key('damage_review_save')));
    await tester.pumpAndSettle();
    expect(repository.reviewCalls, 1);
  });

  testWidgets('failure shows retry', (tester) async {
    await _pump(
      tester,
      FakeDamageRepository()..loadError = const NetworkFailure('offline'),
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('not configured hides the run action', (tester) async {
    await _pump(
      tester,
      FakeDamageRepository(ai: const DamageAiStatus(configured: false)),
    );
    expect(
      find.text('El análisis con IA no está activado en el servidor.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('damage_run')), findsNothing);
  });
}
