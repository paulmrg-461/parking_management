import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/waitlist/application/public_waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/domain/entities/public_waitlist.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';
import 'package:parking_management/features/waitlist/presentation/public_waitlist_card.dart';

import '../../../helpers/fake_public_waitlist_repository.dart';
import '../../../helpers/test_app.dart';

Future<PublicWaitlistCubit> _pump(
  WidgetTester tester,
  FakePublicWaitlistRepository repository, {
  double textScale = 1,
}) async {
  final cubit = PublicWaitlistCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: PublicWaitlistCard(
                  lotId: 1,
                  fullCategories: const [(id: 2, name: 'car')],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Success: the card hides itself when the waitlist is off', (
    tester,
  ) async {
    final repository = FakePublicWaitlistRepository()
      ..infoValue = const PublicWaitlistInfo(
        enabled: false,
        claimMinutes: 15,
        notifyChannel: WaitlistChannel.screen,
      );

    await _pump(tester, repository);

    expect(find.text('Lista de espera'), findsNothing);
  });

  testWidgets('Success: the join form submits the plate, name and phone', (
    tester,
  ) async {
    final repository = FakePublicWaitlistRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byKey(const Key('waitlist-plate')), 'ABC123');
    await tester.enterText(find.byKey(const Key('waitlist-name')), 'Ana');
    await tester.enterText(
      find.byKey(const Key('waitlist-phone')),
      '3001112233',
    );
    await tester.tap(find.byKey(const Key('waitlist-join')));
    await tester.pumpAndSettle();

    expect(repository.joins.single['plate'], 'ABC123');
    expect(repository.joins.single['category_id'], 2);
    expect(find.textContaining('Tu turno: 1'), findsOneWidget);
    expect(find.textContaining('Código 7'), findsOneWidget);
  });

  testWidgets('Success: an offer shows the deadline and the claim button', (
    tester,
  ) async {
    final repository = FakePublicWaitlistRepository();
    final cubit = await _pump(tester, repository);
    await cubit.lookup(7, '3001112233');
    repository.entry = PublicWaitlistEntry.fromJson({
      'id': 7,
      'plate': 'ABC123',
      'category_id': 2,
      'category_name': 'car',
      'status': 'offered',
      'position': 1,
      'wait_until': '2026-01-01T15:00:00Z',
      'hold_minutes': 60,
      'claim_minutes': 15,
      'offer_until': '2026-01-01T16:00:00Z',
      'reservation_id': 5,
      'notify_channel': 'screen',
    });
    await cubit.poll();
    await tester.pumpAndSettle();

    expect(find.text('¡Se liberó un cupo!'), findsOneWidget);
    expect(find.byKey(const Key('waitlist-claim')), findsOneWidget);

    await tester.tap(find.byKey(const Key('waitlist-claim')));
    await tester.pumpAndSettle();

    expect(find.text('¡Reserva confirmada!'), findsOneWidget);
  });

  testWidgets('Failure: a load error offers a retry', (tester) async {
    final repository = FakePublicWaitlistRepository()
      ..infoError = const NetworkFailure('offline');

    await _pump(tester, repository);

    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('A11y: tap targets and labels meet the guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, FakePublicWaitlistRepository());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
  testWidgets('A11y: join form and offer fit 360 dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakePublicWaitlistRepository();
    final cubit = await _pump(tester, repository, textScale: 1.6);
    expect(tester.takeException(), isNull, reason: 'join form');

    await cubit.lookup(7, '3001112233');
    repository.entry = PublicWaitlistEntry.fromJson({
      'id': 7,
      'plate': 'ABC123',
      'category_id': 2,
      'category_name': 'car',
      'status': 'offered',
      'position': 1,
      'wait_until': '2026-01-01T15:00:00Z',
      'hold_minutes': 60,
      'claim_minutes': 15,
      'offer_until': '2026-01-01T16:00:00Z',
      'reservation_id': 5,
      'notify_channel': 'screen',
    });
    await cubit.poll();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'offer card');
    expect(find.byKey(const Key('waitlist-claim')), findsOneWidget);
  });
}
