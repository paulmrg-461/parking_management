import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/domain/entities/user.dart';
import 'package:parking_management/features/users/application/users_cubit.dart';
import 'package:parking_management/features/users/presentation/users_page.dart';

import '../../../helpers/fake_user_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeUserRepository repository;

  Future<void> pumpPage(WidgetTester tester, {List<User>? users}) async {
    repository = FakeUserRepository(
      users ??
          const [
            User(
              id: 1,
              username: 'ana',
              displayName: 'Ana',
              role: UserRole.operator,
            ),
          ],
    );
    await tester.pumpWidget(
      BlocProvider<UsersCubit>(
        create: (_) => UsersCubit(repository),
        child: testApp(const UsersPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: lists users with localized roles', (tester) async {
    await pumpPage(tester);

    expect(find.text('Usuarios'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Operador'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Success: deactivation can be undone from the SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Usuario Ana desactivado'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repository.updates.map((u) => u.isActive), [false, true]);
    expect(repository.users.single.isActive, isTrue);
  });

  testWidgets('Failure: create rejects a PIN that is not 6 digits', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar usuario'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'luis');
    await tester.enterText(fields.at(1), 'Luis');
    await tester.enterText(fields.at(2), '12');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('El PIN debe tener 6 dígitos'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('Empty: no users offers the first user', (tester) async {
    await pumpPage(tester, users: const []);
    expect(find.text('Sin usuarios'), findsOneWidget);
    expect(
      find.text(
        'Agrega el primer operador para empezar a registrar movimientos.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Agregar usuario'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('A11y: labelled switches, 48dp targets, contrast', (
    tester,
  ) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('Success: the role filter narrows the list', (tester) async {
    await pumpPage(
      tester,
      users: const [
        User(
          id: 1,
          username: 'ana',
          displayName: 'Ana',
          role: UserRole.admin,
        ),
        User(
          id: 2,
          username: 'beto',
          displayName: 'Beto',
          role: UserRole.operator,
        ),
      ],
    );

    // The first match is the filter segment; the second is the admin chip
    // on the user row.
    await tester.tap(find.text('Administrador').first);
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
  });

  testWidgets('Success: the search narrows by name or username', (tester) async {
    await pumpPage(
      tester,
      users: const [
        User(
          id: 1,
          username: 'ana',
          displayName: 'Ana',
          role: UserRole.operator,
        ),
        User(
          id: 2,
          username: 'beto',
          displayName: 'Beto',
          role: UserRole.operator,
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'bet');
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsNothing);
    expect(find.text('Beto'), findsOneWidget);
  });

  testWidgets('Failure: a filter with no matches explains itself', (
    tester,
  ) async {
    await pumpPage(tester);

    // The first match is the filter segment; the second is the admin chip
    // on the user row.
    await tester.tap(find.text('Administrador').first);
    await tester.pumpAndSettle();

    expect(find.text('No hay usuarios con este filtro'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });
}
