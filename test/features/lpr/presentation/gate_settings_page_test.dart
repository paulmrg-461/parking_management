import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/categories/application/categories_cubit.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/lpr/application/lpr_settings_cubit.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_settings.dart';
import 'package:parking_management/features/lpr/presentation/gate_settings_page.dart';
import 'package:parking_management/features/users/application/users_cubit.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_lpr_repository.dart';
import '../../../helpers/fake_user_repository.dart';
import '../../../helpers/test_app.dart';

Widget page(
  FakeLprRepository repository, {
  List<Category> categories = const [Category(id: 2, name: 'Carro')],
  List<User> users = const [
    User(id: 7, username: 'gate', displayName: 'Cámara', role: UserRole.operator),
  ],
}) => testApp(
  GateSettingsPage(
    settingsCubit: LprSettingsCubit(repository),
    categoriesCubit: CategoriesCubit(FakeCategoryRepository(categories)),
    usersCubit: UsersCubit(FakeUserRepository(users)),
  ),
);

void main() {
  testWidgets('no cameras shows the devices call to action', (tester) async {
    await tester.pumpWidget(
      page(FakeLprRepository()..settingsValue = fakeLprSettings(cameras: [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay cámaras registradas'), findsOneWidget);
    expect(find.text('Ir a Dispositivos'), findsOneWidget);
  });

  testWidgets('a failure offers retry and recovers', (tester) async {
    final repository = FakeLprRepository()
      ..settingsError = const NetworkFailure('offline');
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repository.settingsError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Modo'), findsOneWidget);
  });

  testWidgets('auto mode asks first and cancel keeps assist', (tester) async {
    await tester.pumpWidget(page(FakeLprRepository()));
    await tester.pumpAndSettle();
    expect(
      find.text('Asistido: el operador confirma cada entrada'),
      findsOneWidget,
    );
    await tester.tap(find.text('Automático'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate_mode_confirm')), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Asistido: el operador confirma cada entrada'),
      findsOneWidget,
    );
  });

  testWidgets('confirming auto and saving sends the mode', (tester) async {
    final repository = FakeLprRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automático'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gate_mode_confirm_yes')));
    await tester.pumpAndSettle();
    expect(find.text('Automático: la cámara registra la entrada'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('gate_settings_save')),
      200,
    );
    await tester.tap(find.byKey(const Key('gate_settings_save')));
    await tester.pumpAndSettle();
    expect(repository.saved.single.mode, LprMode.auto);
    expect(find.text('Ajustes guardados'), findsOneWidget);
  });

  testWidgets('changing a camera direction calls the repository', (tester) async {
    final repository = FakeLprRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sentido de la cámara'), 300);
    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salida').last);
    await tester.pumpAndSettle();
    expect(repository.directions.single, (3, 'exit'));
  });

  testWidgets('the category and user pickers show their names', (tester) async {
    await tester.pumpWidget(page(FakeLprRepository()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Categoría para placas nuevas'), 200);
    await tester.tap(find.text('Categoría para placas nuevas'));
    await tester.pumpAndSettle();
    expect(find.text('Carro'), findsWidgets);
    await tester.tap(find.text('Carro').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Operador del sistema'), 200);
    await tester.tap(find.text('Operador del sistema'));
    await tester.pumpAndSettle();
    expect(find.text('Cámara'), findsWidgets);
  });
}
