import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/presentation/categories_page.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeCategoryRepository repository;

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Category> categories = const [Category(id: 1, name: 'carro')],
    Failure? listError,
  }) async {
    repository = FakeCategoryRepository(categories)..listError = listError;
    await tester.pumpWidget(
      BlocProvider<CategoriesCubit>(
        create: (_) => CategoriesCubit(repository),
        child: testApp(const CategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders the list of categories after load', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('carro'), findsOneWidget);
  });

  testWidgets('Success: delete asks for confirmation before deleting', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Eliminar categoría carro'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar categoría?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.categories, hasLength(1));

    await tester.tap(find.byTooltip('Eliminar categoría carro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(repository.categories, isEmpty);
    expect(find.text('Aún no hay categorías'), findsOneWidget);
  });

  testWidgets('Failure: a failed delete keeps the list and shows a SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.writeError = const ValidationFailure('Category in use');

    await tester.tap(find.byTooltip('Eliminar categoría carro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Category in use'), findsOneWidget);
    expect(find.text('carro'), findsOneWidget);
  });

  testWidgets('Failure: a failed load shows an error with a working retry', (
    tester,
  ) async {
    await pumpPage(tester, listError: const NetworkFailure('offline'));

    expect(find.text('No hay conexión con el servidor'), findsOneWidget);
    repository.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('carro'), findsOneWidget);
  });

  testWidgets('Empty: an empty list shows the empty state', (tester) async {
    await pumpPage(tester, categories: const []);

    expect(find.text('Aún no hay categorías'), findsOneWidget);
  });

  testWidgets('Failure: the create dialog requires a name', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obligatorio'), findsOneWidget);
    expect(repository.categories, hasLength(1));
  });

  testWidgets('A11y: tooltips, 48dp targets and contrast', (tester) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
