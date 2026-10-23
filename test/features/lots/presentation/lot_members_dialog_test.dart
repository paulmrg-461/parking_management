import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/lots/domain/entities/lot_member.dart';
import 'package:parking_management/features/lots/presentation/lot_members_dialog.dart';

import '../../../helpers/test_app.dart';

const _operator = LotMember(
  userId: 2,
  username: 'op',
  displayName: 'Op',
  role: 'operator',
);

void main() {
  testWidgets('Success: members are listed and a role change is reported', (
    tester,
  ) async {
    String? requested;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: LotMembersDialog(
            lotName: 'Central',
            loadMembers: () async => const [_operator],
            onSetRole: (member, role) async {
              requested = role;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Op'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador').last);
    await tester.pumpAndSettle();

    expect(requested, 'admin');
  });

  testWidgets('Empty: a site without users says so', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: LotMembersDialog(
            lotName: 'Central',
            loadMembers: () async => const [],
            onSetRole: (_, _) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esta sede no tiene usuarios'), findsOneWidget);
  });
}
