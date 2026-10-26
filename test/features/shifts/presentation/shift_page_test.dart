import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/shifts/application/shift_cubit.dart';
import 'package:parking_management/features/shifts/presentation/shift_page.dart';

import '../../../helpers/fake_shift_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: opens a shift and shows the reconciliation', (
    tester,
  ) async {
    final repository = FakeShiftRepository();
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const ShiftPage(isAdmin: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay turno abierto'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '10000');
    await tester.tap(find.text('Abrir turno'));
    await tester.pumpAndSettle();

    expect(find.text('Turno abierto'), findsOneWidget);
    expect(find.text('Efectivo esperado'), findsOneWidget);
    expect(find.text('Cerrar turno'), findsOneWidget);
    expect(find.text('Turno abierto correctamente'), findsOneWidget);
  });

  testWidgets('Security: an operator does not see the admin history', (
    tester,
  ) async {
    final repository = FakeShiftRepository(
      historyShifts: [sampleShift(closed: true)],
    );
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const ShiftPage(isAdmin: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turnos recientes'), findsNothing);
  });

  testWidgets('Success: closing a shift confirms it in a SnackBar', (
    tester,
  ) async {
    final repository = FakeShiftRepository(currentShift: sampleShift());
    final cubit = ShiftCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const ShiftPage(isAdmin: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar turno'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Efectivo contado'),
      '25000',
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Turno cerrado correctamente'), findsOneWidget);
    expect(find.text('No hay turno abierto'), findsOneWidget);
  });
}
