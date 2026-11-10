import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    void Function(BuildContext context, String plate)? onCheckIn,
    Size size = const Size(800, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          child: ReservationsPage(onCheckIn: onCheckIn),
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
    expect(find.text('Reserva cancelada'), findsOneWidget);
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

  testWidgets('Success: the empty state explains holds and offers to add one', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('No hay reservas activas'), findsOneWidget);
    expect(
      find.text('Reserva el cupo de un cliente para asegurar su entrada.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Nueva reserva'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Success: the search and expiring filters narrow the list', (
    tester,
  ) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          id: 1,
          plate: 'SOON01',
          reservedUntil: DateTime.now().add(const Duration(minutes: 20)),
        ),
        sampleReservation(
          id: 2,
          plate: 'LATE01',
          reservedUntil: DateTime.now().add(const Duration(hours: 8)),
        ),
      ],
    );

    expect(find.text('2 reservas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'late');
    await tester.pumpAndSettle();
    expect(find.text('SOON01'), findsNothing);
    expect(find.text('LATE01'), findsOneWidget);

    await tester.tap(find.text('Solo por vencer'));
    await tester.pumpAndSettle();
    expect(find.text('Ninguna reserva coincide con el filtro'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros').first);
    await tester.pumpAndSettle();
    expect(find.text('SOON01'), findsOneWidget);
    expect(find.text('2 reservas'), findsOneWidget);
  });

  testWidgets('Success: a reservation opens check-in with its plate', (
    tester,
  ) async {
    String? requested;
    await pumpPage(
      tester,
      reservations: [sampleReservation(plate: 'ABC123')],
      onCheckIn: (_, plate) => requested = plate,
    );

    await tester.tap(find.byTooltip('Registrar entrada'));
    await tester.pumpAndSettle();

    expect(requested, 'ABC123');
  });

  testWidgets('Success: a public booking shows who booked it', (tester) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          plate: 'WEB123',
          customerName: 'Ana Perez',
          customerPhone: '3009998877',
          source: 'public',
        ),
      ],
    );

    expect(find.byKey(const Key('reservation_public')), findsOneWidget);
    expect(find.text('Web'), findsOneWidget);
    expect(find.text('Ana Perez · 3009998877'), findsOneWidget);
    expect(find.byTooltip('Llamar al cliente'), findsOneWidget);
    expect(find.byTooltip('WhatsApp al cliente'), findsOneWidget);
  });

  testWidgets('Success: the web filter hides the operator holds', (
    tester,
  ) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(id: 1, plate: 'AAA111'),
        sampleReservation(
          id: 2,
          plate: 'WEB123',
          customerName: 'Ana Perez',
          customerPhone: '3009998877',
          source: 'public',
        ),
      ],
    );

    await tester.tap(find.text('Solo web'));
    await tester.pumpAndSettle();

    expect(find.text('AAA111'), findsNothing);
    expect(find.text('WEB123'), findsOneWidget);
    expect(find.text('1 reservas'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros').first);
    await tester.pumpAndSettle();
    expect(find.text('AAA111'), findsOneWidget);
  });

  testWidgets('Security: an operator hold has no customer actions', (
    tester,
  ) async {
    await pumpPage(tester, reservations: [sampleReservation(plate: 'ABC123')]);

    expect(find.byKey(const Key('reservation_public')), findsNothing);
    expect(find.byTooltip('Llamar al cliente'), findsNothing);
    expect(find.byTooltip('WhatsApp al cliente'), findsNothing);
  });

  testWidgets('Success: a late hold is flagged as in grace', (tester) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          id: 3,
          plate: 'LATE01',
          reservedUntil: DateTime.now().subtract(const Duration(minutes: 5)),
          inGrace: true,
        ),
      ],
    );

    expect(find.byKey(const Key('reservation_in_grace')), findsOneWidget);
    expect(find.text('En tolerancia'), findsOneWidget);
  });

  testWidgets('Success: the card shows the code the customer was given', (
    tester,
  ) async {
    await pumpPage(tester, reservations: [sampleReservation(id: 12)]);

    expect(find.textContaining('#12 ·'), findsOneWidget);
  });

  testWidgets('Success: the search finds a booking by its code', (
    tester,
  ) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(id: 7, plate: 'AAA111'),
        sampleReservation(id: 12, plate: 'BBB222'),
      ],
    );

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pumpAndSettle();

    expect(find.text('AAA111'), findsNothing);
    expect(find.text('BBB222'), findsOneWidget);
  });

  testWidgets('Success: the search finds a booking by customer', (
    tester,
  ) async {
    await pumpPage(
      tester,
      reservations: [
        sampleReservation(id: 1, plate: 'AAA111'),
        sampleReservation(
          id: 2,
          plate: 'BBB222',
          customerName: 'Carlos Ruiz',
          customerPhone: '3005556677',
          source: 'public',
        ),
      ],
    );

    await tester.enterText(find.byType(TextField).first, 'carlos');
    await tester.pumpAndSettle();

    expect(find.text('AAA111'), findsNothing);
    expect(find.text('BBB222'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '3005556677');
    await tester.pumpAndSettle();
    expect(find.text('BBB222'), findsOneWidget);
  });

  testWidgets('A11y: a public booking fits a 400 px phone', (tester) async {
    await pumpPage(
      tester,
      size: const Size(400, 1200),
      reservations: [
        sampleReservation(
          plate: 'WEB123',
          customerName: 'Ana Maria Perez Rodriguez',
          customerPhone: '3009998877',
          notes: 'Llega a las 8',
          source: 'public',
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('reservation_public')), findsOneWidget);
  });

  testWidgets('Success: the CSV button copies the visible holds', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpPage(
      tester,
      reservations: [
        sampleReservation(
          id: 7,
          plate: 'WEB123',
          customerName: 'Ana',
          customerPhone: '3009998877',
          source: 'public',
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('reservations_csv')));
    await tester.pumpAndSettle();

    final copy = calls.firstWhere((c) => c.method == 'Clipboard.setData');
    final text = (copy.arguments as Map)['text'] as String;
    expect(text, contains('code,plate,category,reserved_until'));
    expect(text, contains('7,WEB123,car'));
    expect(text, contains('Ana'));
    expect(text, contains('3009998877,public,active'));
    expect(find.text('Reservas copiadas en CSV'), findsOneWidget);
  });

  testWidgets('Success: the reservation plate is uppercased while typing', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Nueva reserva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'abc123');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'ABC123',
    );
  });

  testWidgets('Success: a quick hold presets the expiry time', (tester) async {
    final repository = await pumpPage(tester);
    await tester.tap(find.byTooltip('Nueva reserva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'abc123');
    await tester.tap(find.text('+4 h'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final until = repository.createdUntil!;
    expect(until.difference(DateTime.now()).inMinutes, closeTo(240, 3));
  });

  testWidgets('Success: the hold can end at the end of the day', (
    tester,
  ) async {
    final repository = await pumpPage(tester);
    await tester.tap(find.byTooltip('Nueva reserva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'abc123');
    await tester.tap(find.text('Fin del día'));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final until = repository.createdUntil!;
    final now = DateTime.now();
    expect(until.year, now.year);
    expect(until.month, now.month);
    expect(until.day, now.day);
    expect(until.hour, 23);
    expect(until.minute, 59);
  });
}
