import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/presentation/monthly_passes_page.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_monthly_pass_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeMonthlyPassRepository repository;

  Future<void> pumpPage(WidgetTester tester, {Failure? listError}) async {
    repository = FakeMonthlyPassRepository()..listError = listError;
    await tester.pumpWidget(
      testApp(
        BlocProvider<MonthlyPassesCubit>(
          create: (_) => MonthlyPassesCubit(
            repository,
            FakeVehicleRepository(const [
              Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
            ]),
          ),
          child: const MonthlyPassesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders passes with plates, es_CO dates and COP', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Mensualidades'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('1/1/2026 – 31/1/2026 · \$100.000'), findsOneWidget);
  });

  testWidgets('Failure: a failed toggle keeps the list and shows a SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.writeError = const ValidationFailure('Pass expired');

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Pass expired'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('Success: deactivation can be undone', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repository.updates.map((u) => u.active), [false, true]);
  });

  testWidgets(
    'Security: delete asks for confirmation before calling the cubit',
    (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Eliminar mensualidad de ABC123'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);

      await tester.tap(find.byTooltip('Eliminar mensualidad de ABC123'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(repository.deleted, [1]);
    },
  );

  testWidgets('Failure: create requires dates and a positive amount', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar mensualidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(find.text('Ingresa un valor mayor a 0'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('Failure: load error shows retry', (tester) async {
    await pumpPage(tester, listError: const NetworkFailure());
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('A11y: tooltips, 48dp targets and contrast', (tester) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
