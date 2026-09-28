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
    expect(find.text('ana · Operador'), findsOneWidget);
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

  testWidgets('Failure: create rejects a PIN that is not 4-6 digits', (
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

    expect(find.text('El PIN debe tener de 4 a 6 dígitos'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('Empty: no users shows the empty state', (tester) async {
    await pumpPage(tester, users: const []);
    expect(find.text('Aún no hay usuarios'), findsOneWidget);
  });

  testWidgets('A11y: labelled switches, 48dp targets, contrast', (
    tester,
  ) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
