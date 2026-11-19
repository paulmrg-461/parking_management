import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/loyalty/application/loyalty_status_cubit.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_status.dart';
import 'package:parking_management/features/loyalty/presentation/loyalty_progress_chip.dart';

import '../../../helpers/fake_loyalty_repository.dart';
import '../../../helpers/test_app.dart';

Future<LoyaltyStatusCubit> _pump(
  WidgetTester tester,
  FakeLoyaltyRepository repository, {
  bool load = true,
}) async {
  final cubit = LoyaltyStatusCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<LoyaltyStatusCubit>.value(
        value: cubit,
        child: const Scaffold(body: LoyaltyProgressChip()),
      ),
    ),
  );
  if (load) {
    await cubit.load('ABC123');
    await tester.pump();
  }
  return cubit;
}

void main() {
  testWidgets('Success: shows visit n of N', (tester) async {
    await _pump(tester, FakeLoyaltyRepository());

    expect(find.text('Visita 4 de 5'), findsOneWidget);
    expect(find.byKey(const Key('loyalty_progress_chip')), findsOneWidget);
    expect(find.byKey(const Key('loyalty_reward_badge')), findsNothing);
  });

  testWidgets('Success: shows the reward badge', (tester) async {
    await _pump(
      tester,
      FakeLoyaltyRepository(
        statusResult: const LoyaltyStatus(
          enabled: true,
          visits: 2,
          required: 5,
          nextVisit: 3,
          rewardCount: 1,
        ),
      ),
    );

    expect(find.text('Recompensa disponible'), findsOneWidget);
    expect(find.byKey(const Key('loyalty_reward_badge')), findsOneWidget);
  });

  testWidgets('Success: hidden when idle', (tester) async {
    await _pump(tester, FakeLoyaltyRepository(), load: false);
    expect(find.byKey(const Key('loyalty_progress_chip')), findsNothing);
    expect(find.textContaining('Visita'), findsNothing);
  });

  testWidgets('Success: skeleton while loading', (tester) async {
    final cubit = LoyaltyStatusCubit(FakeLoyaltyRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider<LoyaltyStatusCubit>.value(
          value: cubit,
          child: const Scaffold(body: LoyaltyProgressChip()),
        ),
      ),
    );
    cubit.emit(const LoyaltyStatusLoading());
    await tester.pump();
    expect(find.byKey(const Key('loyalty_progress_chip')), findsNothing);
  });

  testWidgets('Failure: offers retry and recovers', (tester) async {
    final repository = FakeLoyaltyRepository()
      ..statusError = const ValidationFailure(
        'InvalidPlateError',
        'InvalidPlateError',
      );
    final cubit = await _pump(tester, repository);

    expect(cubit.state, isA<LoyaltyStatusFailure>());
    expect(find.byKey(const Key('loyalty_chip_retry')), findsOneWidget);

    repository.statusError = null;
    await tester.tap(find.byKey(const Key('loyalty_chip_retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Visita 4 de 5'), findsOneWidget);
  });
}
