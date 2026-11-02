import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/presentation/capacity_dialog.dart';
import 'package:parking_management/features/lots/presentation/create_lot_dialog.dart';
import 'package:parking_management/features/monthly_passes/presentation/monthly_pass_dialog.dart';
import 'package:parking_management/features/reservations/presentation/reservation_dialog.dart';
import 'package:parking_management/features/tariffs/presentation/create_tariff_dialog.dart';
import 'package:parking_management/features/users/presentation/create_user_dialog.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/presentation/create_vehicle_dialog.dart';

import '../../helpers/test_app.dart';

const _category = Category(id: 1, name: 'car');

/// Pumps a dialog at the narrowest phone width and fails on any layout
/// exception (overflow, unbounded constraints, ...).
Future<void> _pumpAtPhone(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(Scaffold(body: dialog)));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Security: create dialogs fit a 400 px phone', (tester) async {
    final dialogs = <String, Widget>{
      'vehicle': CreateVehicleDialog(
        categories: const [_category],
        onCreate: (_) {},
      ),
      'tariff': CreateTariffDialog(
        categories: const [_category],
        onCreate: (_) {},
      ),
      'user': CreateUserDialog(onCreate: (_) {}),
      'lot': CreateLotDialog(onCreate: (_) async {}),
      'reservation': const ReservationDialog(categories: [_category]),
      'monthly pass': MonthlyPassDialog(
        vehicles: const [Vehicle(id: 1, plate: 'ABC123', categoryId: 1)],
        onSave: (_) {},
      ),
      'capacity': CapacityDialog(category: _category, onSave: (_) {}),
    };

    for (final entry in dialogs.entries) {
      await _pumpAtPhone(tester, entry.value);
      // The action row stays reachable no matter how tall the content is.
      expect(
        find.byType(TextButton),
        findsWidgets,
        reason: '${entry.key} lost its actions',
      );
    }
  });
}
