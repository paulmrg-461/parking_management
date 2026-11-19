import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/waitlist/application/waitlist_cubit.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_settings.dart';
import 'package:parking_management/features/waitlist/presentation/waitlist_section.dart';

import '../../../helpers/fake_waitlist_repository.dart';
import '../../../helpers/test_app.dart';

WaitlistEntry _entry(int id, {String status = 'waiting'}) => WaitlistEntry(
  id: id,
  plate: 'ABC10$id',
  categoryId: 2,
  categoryName: 'car',
  customerName: 'Ana',
  customerPhone: '300111223$id',
  status: waitlistStatusFrom(status),
  waitUntil: DateTime.now().add(const Duration(hours: 3)),
  holdMinutes: 60,
  offerUntil: status == 'offered'
      ? DateTime.now().add(const Duration(minutes: 15))
      : null,
  reservationId: status == 'offered' ? 90 : null,
  position: id,
  createdAt: DateTime.now(),
);

Future<WaitlistCubit> _pump(
  WidgetTester tester,
  FakeWaitlistRepository repository,
) async {
  final cubit = WaitlistCubit(repository);
  addTearDown(cubit.close);
  await tester.runAsync(cubit.load);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(
          body: SingleChildScrollView(child: WaitlistSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Empty: guidance when nobody is queuing', (tester) async {
    await _pump(tester, FakeWaitlistRepository());

    expect(find.text('Nadie en lista de espera'), findsOneWidget);
    expect(
      find.textContaining('Cuando el parqueadero se llene'),
      findsOneWidget,
    );
  });

  testWidgets('Success: lists entries with position and contact', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeWaitlistRepository()..entries = [_entry(1), _entry(2)],
    );

    expect(find.text('ABC101'), findsOneWidget);
    expect(find.textContaining('Ana · 3001112231'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Success: an offered entry shows its deadline and claim button', (
    tester,
  ) async {
    final repository = FakeWaitlistRepository()
      ..entries = [_entry(3, status: 'offered')];
    await _pump(tester, repository);

    expect(find.textContaining('Oferta hasta'), findsOneWidget);
    expect(
      find.text('Llamar: el cliente no tiene WhatsApp automático'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('waitlist-claim-3')));
    await tester.pumpAndSettle();

    expect(repository.claimed, [3]);
  });

  testWidgets('Success: removing asks for confirmation', (tester) async {
    final repository = FakeWaitlistRepository()..entries = [_entry(4)];
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('waitlist-remove-4')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se quitará a ABC104'), findsOneWidget);

    await tester.tap(find.text('Quitar de la lista').last);
    await tester.pumpAndSettle();

    expect(repository.removed, [4]);
  });

  testWidgets('Security: the settings action is hidden without an admin', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeWaitlistRepository()
        ..entries = [_entry(5)]
        ..settings = const WaitlistSettings(
          enabled: true,
          claimMinutes: 15,
          maxEntries: 30,
        ),
    );

    expect(find.byKey(const Key('waitlist-settings')), findsNothing);
  });

  testWidgets('Failure: a load error offers a retry', (tester) async {
    await _pump(
      tester,
      FakeWaitlistRepository()..listError = const NetworkFailure('offline'),
    );

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
