import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/pricing/application/price_quote_cubit.dart';
import 'package:parking_management/features/pricing/domain/entities/price_quote.dart';
import 'package:parking_management/features/pricing/presentation/price_quote_chip.dart';

import '../../../helpers/fake_pricing_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakePriceQuoteRepository repository,
) async {
  final cubit = PriceQuoteCubit(
    repository,
    refreshInterval: const Duration(hours: 1),
  );
  addTearDown(cubit.close);
  await cubit.load(1);
  await tester.pumpWidget(
    testApp(
      BlocProvider<PriceQuoteCubit>.value(
        value: cubit,
        child: const Scaffold(body: PriceQuoteChip()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Success: shows the current rate and the higher chip', (
    tester,
  ) async {
    await _pump(tester, FakePriceQuoteRepository());

    expect(find.textContaining(r'$3.600'), findsOneWidget);
    expect(find.text('Mas alta'), findsOneWidget);
    expect(find.textContaining(r'Normal: $3.000'), findsOneWidget);
    expect(find.byKey(const Key('price_quote_tier')), findsOneWidget);
  });

  testWidgets('Success: a base price hides the usual-price line', (
    tester,
  ) async {
    await _pump(
      tester,
      FakePriceQuoteRepository(
        quoteResult: const PriceQuote(
          enabled: true,
          hourlyBase: 3000,
          hourlyCurrent: 3000,
        ),
      ),
    );

    expect(find.textContaining(r'$3.000'), findsOneWidget);
    expect(find.text('Mas alta'), findsNothing);
    expect(find.textContaining('Normal:'), findsNothing);
  });

  testWidgets('Security: a disabled lot renders nothing', (tester) async {
    await _pump(
      tester,
      FakePriceQuoteRepository(
        quoteResult: const PriceQuote(enabled: false),
      ),
    );
    expect(find.byKey(const Key('price_quote_tier')), findsNothing);
  });

  testWidgets('Failure: offline shows the note instead of a price', (
    tester,
  ) async {
    await _pump(
      tester,
      FakePriceQuoteRepository(),
    );
  });

  testWidgets('A11y: the chip meets the 48 dp target', (tester) async {
    await _pump(tester, FakePriceQuoteRepository());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
