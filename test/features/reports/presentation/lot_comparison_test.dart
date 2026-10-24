import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/reports/domain/entities/revenue_report.dart';
import 'package:parking_management/features/reports/presentation/widgets/lot_comparison.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('Success: sites are sorted by revenue with their share', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        LotComparison(
          lots: const [
            LotRevenue(lotId: 1, lotName: 'Central', amount: 100, tickets: 2, avgTicket: 50),
            LotRevenue(lotId: 2, lotName: 'North', amount: 300, tickets: 3, avgTicket: 100),
            LotRevenue(lotId: 3, lotName: 'Empty', amount: 0),
          ],
        ),
      ),
    );

    final north = tester.getTopLeft(find.text('North')).dy;
    final central = tester.getTopLeft(find.text('Central')).dy;
    expect(north, lessThan(central));

    expect(find.text('75% del total'), findsOneWidget);
    expect(find.text('25% del total'), findsOneWidget);
    expect(find.text('0% del total'), findsOneWidget);
    expect(find.textContaining('3 salidas'), findsOneWidget);
    expect(find.textContaining('promedio'), findsNWidgets(3));
  });

  testWidgets('Failure: an all-zero period shows no percentage', (tester) async {
    await tester.pumpWidget(
      testApp(
        const LotComparison(
          lots: [LotRevenue(lotId: 1, lotName: 'Central', amount: 0)],
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });
}
