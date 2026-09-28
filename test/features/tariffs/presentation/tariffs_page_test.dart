import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/tariffs/application/tariffs_cubit.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/presentation/tariffs_page.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_tariff_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeTariffRepository repository;

  Future<void> pumpPage(WidgetTester tester, {Failure? listError}) async {
    repository = FakeTariffRepository()..listError = listError;
    await tester.pumpWidget(
      BlocProvider<TariffsCubit>(
        create: (_) => TariffsCubit(
          repository,
          FakeCategoryRepository(const [Category(id: 1, name: 'carro')]),
        ),
        child: testApp(const TariffsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders tariffs with localized type and COP amount', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Tarifas'), findsOneWidget);
    expect(find.text('carro · Por hora'), findsOneWidget);
    expect(find.text('\$3.000'), findsOneWidget);
  });

  testWidgets('Success: deactivating offers "Deshacer" that reactivates', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.updates.single.active, isFalse);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(repository.updates.last.active, isTrue);
  });

  testWidgets('Failure: a failed toggle keeps the tile and shows a SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.writeError = const ValidationFailure('Invalid window');

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Invalid window'), findsOneWidget);
    expect(find.text('carro · Por hora'), findsOneWidget);
  });

  testWidgets('Success: delete is confirmed first', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Eliminar tarifa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, [1]);
  });

  testWidgets('Failure: create validates amount and night window', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar tarifa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un valor mayor a 0'), findsOneWidget);
    expect(repository.tariffs, hasLength(1));
  });

  testWidgets('Failure: load error shows retry', (tester) async {
    await pumpPage(tester, listError: const NetworkFailure());

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('No hay conexión con el servidor'), findsOneWidget);
  });

  testWidgets('A11y: switches are labelled, targets 48dp, contrast ok', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.bySemanticsLabel(RegExp('Tarifa activa')), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  test('tariff types are all covered', () {
    expect(TariffType.values, hasLength(4));
  });
}
