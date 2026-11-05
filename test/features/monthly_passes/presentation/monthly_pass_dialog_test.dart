import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/presentation/monthly_pass_dialog.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/test_app.dart';

const _vehicles = [
  Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
  Vehicle(id: 2, plate: 'XYZ999', categoryId: 2),
];

String _amount(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('monthly_pass_amount')))
    .controller!
    .text;

void main() {
  testWidgets('Success: the monthly tariff prefills and follows the vehicle', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: MonthlyPassDialog(
            vehicles: _vehicles,
            monthlyTariffs: const {1: 120000, 2: 90000},
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_amount(tester), '120000');

    await tester.tap(find.text('ABC123'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XYZ999').last);
    await tester.pumpAndSettle();

    expect(_amount(tester), '90000');
  });

  testWidgets('Security: editing keeps the saved amount and can reuse the tariff', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: MonthlyPassDialog(
            vehicles: _vehicles,
            monthlyTariffs: const {1: 120000},
            existing: MonthlyPass(
              id: 1,
              vehicleId: 1,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 1, 31),
              amount: 100000,
            ),
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_amount(tester), '100000');
    expect(
      find.byKey(const Key('monthly_pass_use_tariff')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('monthly_pass_amount')),
      '',
    );
    await tester.tap(find.byKey(const Key('monthly_pass_use_tariff')));
    await tester.pumpAndSettle();
    expect(_amount(tester), '120000');
  });
}
