import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/policies/application/policies_cubit.dart';
import 'package:parking_management/features/policies/domain/entities/lot_profile.dart';
import 'package:parking_management/features/policies/presentation/policies_page.dart';

import '../../../helpers/fake_policy_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> pumpPage(
  WidgetTester tester,
  FakePolicyRepository repository, {
  int? lotId = 1,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = PoliciesCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<PoliciesCubit>.value(
        value: cubit,
        child: PoliciesPage(lotId: lotId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: renders the lot identity and the policy', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakePolicyRepository(
        profile: const LotProfile(
          id: 1,
          name: 'Parqueadero DevPaul',
          address: 'Tv 7 #51N-24',
          schedule: '24 horas',
          phone: '3013495689',
          legalPolicy:
              'POLÍTICAS DE {{parking}}\nAtendemos {{schedule}} en {{address}}.',
        ),
      ),
    );

    expect(find.text('Parqueadero DevPaul'), findsOneWidget);
    expect(find.text('Tv 7 #51N-24'), findsWidgets);
    expect(find.textContaining('POLÍTICAS DE Parqueadero DevPaul'), findsOneWidget);
    expect(find.textContaining('Atendemos 24 horas'), findsOneWidget);
  });

  testWidgets('Failure: an unknown lot shows the error with retry', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakePolicyRepository(
        error: const ValidationFailure('nope', 'PolicyNotFoundError'),
      ),
    );

    expect(
      find.text('No pudimos cargar las políticas de este parqueadero.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Success: an empty policy says so', (tester) async {
    await pumpPage(
      tester,
      FakePolicyRepository(profile: const LotProfile(id: 1, name: 'Sede')),
    );

    expect(
      find.text('Este parqueadero aún no publicó sus políticas.'),
      findsOneWidget,
    );
  });
}
