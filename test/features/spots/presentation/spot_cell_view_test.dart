import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/theme/status_colors.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/presentation/widgets/spot_cell_view.dart';

import '../../../helpers/test_app.dart';

const _spot = ParkingSpot(
  id: 1,
  code: 'A1',
  group: SlotGroup.car,
  row: 0,
  col: 0,
);

Future<Color> cellColor(WidgetTester tester, {required bool occupied}) async {
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: SpotCellView(
          spot: _spot,
          primary: occupied ? 'ABC123' : 'A1',
          secondary: occupied ? '10 min' : 'Libre',
          occupied: occupied,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(SpotCellView),
      matching: find.byType(Container),
    ).first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('Success: an occupied bay is blue, a free one green', (
    tester,
  ) async {
    final free = await cellColor(tester, occupied: false);
    final taken = await cellColor(tester, occupied: true);

    expect(free, isNot(taken));
    final context = tester.element(find.byType(SpotCellView));
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    expect(
      taken,
      Color.alphaBlend(scheme.primary.withValues(alpha: 0.18), scheme.surface),
    );
    expect(
      free,
      Color.alphaBlend(status.success.withValues(alpha: 0.14), scheme.surface),
    );
  });
}
