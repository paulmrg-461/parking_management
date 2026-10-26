import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/reservations/application/reservations_cubit.dart';
import 'package:parking_management/features/reservations/presentation/reservations_page.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  Future<FakeReservationRepository> pumpPage(
    WidgetTester tester, {
    List<dynamic> reservations = const [],
  }) async {
    final repository = FakeReservationRepository([
      for (final reservation in reservations) reservation,
    ]);
    final cubit = ReservationsCubit(
      repository,
      FakeCategoryRepository(const [Category(id: 2, name: 'car')]),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const ReservationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Success: active reservations are listed', (tester) async {
    await pumpPage(tester, reservations: [sampleReservation(notes: 'vip')]);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.textContaining('vip'), findsOneWidget);
  });

  testWidgets('Empty: no reservations shows the empty state', (tester) async {
    await pumpPage(tester);

    expect(find.text('No hay reservas activas'), findsOneWidget);
  });

  testWidgets('Security: cancelling requires an explicit confirmation', (
    tester,
  ) async {
    final repository = await pumpPage(
      tester,
      reservations: [sampleReservation()],
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(repository.cancelledId, isNull);

    await tester.tap(find.text('Cancelar reserva').last);
    await tester.pumpAndSettle();

    expect(repository.cancelledId, 1);
    expect(find.text('No hay reservas activas'), findsOneWidget);
  });

  testWidgets('Success: a hold about to lapse is flagged', (tester) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          reservedUntil: DateTime.now().add(const Duration(minutes: 30)),
        ),
      ],
    );

    expect(find.textContaining('Vence en'), findsOneWidget);
  });

  testWidgets('Failure: a distant hold is not flagged', (tester) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          reservedUntil: DateTime.now().add(const Duration(hours: 5)),
        ),
      ],
    );

    expect(find.textContaining('Vence en'), findsNothing);
  });

  testWidgets('Success: the soonest expiry is listed first', (tester) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          id: 2,
          plate: 'LATE01',
          reservedUntil: DateTime.now().add(const Duration(hours: 6)),
        ),
        sampleReservation(
          id: 1,
          plate: 'SOON01',
          reservedUntil: DateTime.now().add(const Duration(minutes: 15)),
        ),
      ],
    );

    final first = tester.getTopLeft(find.text('SOON01')).dy;
    final second = tester.getTopLeft(find.text('LATE01')).dy;
    expect(first, lessThan(second));
  });
}
