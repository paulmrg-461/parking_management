import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/diagnostics/application/diagnostics_cubit.dart';
import 'package:parking_management/features/diagnostics/presentation/diagnostics_page.dart';

import '../../../helpers/fake_diagnostics_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> pumpPage(
  WidgetTester tester, {
  int staleSessions = 0,
  int deadPush = 0,
  List<dynamic> errors = const [],
  List<dynamic> whatsapp = const [],
}) async {
  final cubit = DiagnosticsCubit(
    FakeDiagnosticsRepository(
      snapshot: sampleSnapshot(
        staleSessions: staleSessions,
        deadPush: deadPush,
        clientErrors: errors.length,
        whatsappFailed: whatsapp.where((m) => m.status == 'failed').length,
      ),
      errors: [for (final error in errors) error],
      whatsapp: [for (final message in whatsapp) message],
    ),
  );
  addTearDown(cubit.close);
  // Tall viewport: the sections sit below the default 800x600 fold and
  // ListView builds lazily.
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(value: cubit, child: const DiagnosticsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: renders the operational counters', (tester) async {
    await pumpPage(tester);

    expect(find.text('Diagnóstico'), findsOneWidget);
    expect(find.text('Sesiones abiertas'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('evidence'), findsOneWidget);
  });

  testWidgets('Success: a client error opens its detail', (tester) async {
    await pumpPage(tester, errors: [sampleError()]);

    expect(find.text('Bad state: boom'), findsOneWidget);
    await tester.tap(find.text('Bad state: boom'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del error'), findsOneWidget);
    expect(find.textContaining('#0 main'), findsOneWidget);
  });

  testWidgets('Empty: no errors shows the calm state', (tester) async {
    await pumpPage(tester);

    expect(
      find.text('Sin errores reportados en los últimos 7 días'),
      findsOneWidget,
    );
  });

  testWidgets('A11y: a warning state is announced with an icon', (
    tester,
  ) async {
    await pumpPage(tester, staleSessions: 2, deadPush: 5);

    // The system card switches to the warning icon when something needs
    // attention; the values themselves are covered by the counter test.
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.text('Sesiones abiertas +24 h'), findsOneWidget);
  });

  testWidgets('Success: the WhatsApp queue shows failures and messages', (
    tester,
  ) async {
    await pumpPage(tester, whatsapp: [sampleWhatsapp()]);

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Fallidos'), findsOneWidget);
    expect(find.text('receipt · 573001112233'), findsOneWidget);
    expect(find.textContaining('401: invalid token'), findsOneWidget);
  });

  testWidgets('Empty: no WhatsApp messages shows its empty state', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(
      find.text('Sin mensajes de WhatsApp en el periodo'),
      findsOneWidget,
    );
  });
}
