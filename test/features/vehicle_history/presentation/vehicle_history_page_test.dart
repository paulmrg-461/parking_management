import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/vehicle_history/application/vehicle_history_cubit.dart';
import 'package:parking_management/features/vehicle_history/presentation/vehicle_history_page.dart';

import '../../../helpers/fake_vehicle_history_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: searches a plate and renders its timeline', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(history: sampleHistory());
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'abc 123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('TCK-000002'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(repository.lookups, ['ABC123']);
  });

  testWidgets('Failure: an unknown plate shows the localized error', (
    tester,
  ) async {
    final repository = FakeVehicleHistoryRepository(
      error: const ValidationFailure(
        'VehicleNotFoundError',
        'VehicleNotFoundError',
      ),
    );
    final cubit = VehicleHistoryCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const VehicleHistoryPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ZZZ999');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Vehículo no encontrado'), findsOneWidget);
  });
}
