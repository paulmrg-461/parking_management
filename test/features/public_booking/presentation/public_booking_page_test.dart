import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/application/public_booking_cubit.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';
import 'package:parking_management/features/public_booking/presentation/public_booking_page.dart';

import '../../../helpers/fake_public_booking_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakePublicBookingRepository> _pump(
  WidgetTester tester, {
  FakePublicBookingRepository? repository,
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo =
      repository ??
      (FakePublicBookingRepository()
        ..availabilityToReturn = sampleAvailability());
  final cubit = PublicBookingCubit(repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<PublicBookingCubit>.value(
        value: cubit,
        child: const PublicBookingPage(lotId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('Success: shows the lot, availability and the form', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Reserva tu espacio'), findsOneWidget);
    expect(find.text('Parqueadero Central'), findsOneWidget);
    expect(find.text('Disponibilidad ahora'), findsOneWidget);
    expect(find.text('4 disponibles'), findsWidgets);
    expect(find.text('Reservar espacio'), findsOneWidget);
  });

  testWidgets('Success: a full category cannot be selected', (tester) async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability(full: true);
    await _pump(tester, repository: repository);

    expect(find.text('Completo'), findsWidgets);
    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();

    // No selected card and the submit still asks for a category.
    await tester.enterText(find.byType(TextField).at(0), 'ABC123');
    await tester.enterText(find.byType(TextField).at(1), '3001112233');
    await tester.tap(find.text('Reservar espacio'));
    await tester.pumpAndSettle();

    expect(find.text('Elige un tipo de vehículo'), findsOneWidget);
  });

  testWidgets('Success: selecting a category books the space', (tester) async {
    final repository = await _pump(tester);

    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'abc123');
    await tester.enterText(find.byType(TextField).at(1), '3001112233');
    await tester.enterText(find.byType(TextField).at(2), 'Ana');
    await tester.tap(find.text('Reservar espacio'));
    await tester.pumpAndSettle();

    expect(repository.lastPlate, 'ABC123');
    expect(repository.lastCategoryId, 2);
    expect(repository.lastPhone, '3001112233');
    expect(repository.lastName, 'Ana');
    expect(find.text('¡Reserva confirmada!'), findsOneWidget);
    expect(find.text('#12'), findsOneWidget);
  });

  testWidgets('Failure: the form validates plate and phone', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Reservar espacio'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa una placa válida.'), findsOneWidget);
    expect(
      find.text('Ingresa un teléfono válido (7 a 15 dígitos).'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a rejected reservation shows the reason', (
    tester,
  ) async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = sampleAvailability()
      ..reserveError = const ValidationFailure(
        'CategoryFullError',
        'CategoryFullError',
      );
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ABC123');
    await tester.enterText(find.byType(TextField).at(1), '3001112233');
    await tester.tap(find.text('Reservar espacio'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ese tipo de vehículo ya no tiene espacio. Elige otro o intenta más tarde.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Empty: a lot without categories explains itself', (
    tester,
  ) async {
    final repository = FakePublicBookingRepository()
      ..availabilityToReturn = const PublicBookingAvailability(
        lotId: 1,
        lotName: 'Central',
      );
    await _pump(tester, repository: repository);

    expect(
      find.text('No hay tipos de vehículo configurados. Llama al parqueadero.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure: a load error offers a retry', (tester) async {
    final repository = FakePublicBookingRepository()
      ..availabilityError = const NetworkFailure('offline');
    await _pump(tester, repository: repository);

    expect(find.text('Reintentar'), findsOneWidget);
    repository
      ..availabilityError = null
      ..availabilityToReturn = sampleAvailability();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Disponibilidad ahora'), findsOneWidget);
  });

  testWidgets('A11y: the public page fits a phone', (tester) async {
    await _pump(tester, size: const Size(400, 2200));

    expect(tester.takeException(), isNull);
    expect(find.text('Reserva tu espacio'), findsOneWidget);
  });
}
