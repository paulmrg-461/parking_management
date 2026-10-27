import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/monthly_passes/application/monthly_passes_cubit.dart';
import 'package:parking_management/features/monthly_passes/presentation/monthly_passes_page.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/features/customer_messages/domain/repositories/customer_message_repository.dart';
import 'package:parking_management/features/settings/application/branding_cubit.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass_payment.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_customer_message_repository.dart';
import '../../../helpers/fake_monthly_pass_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeMonthlyPassRepository repository;

  Future<void> pumpPage(
    WidgetTester tester, {
    Failure? listError,
    String? ownerPhone,
    bool whatsappAuto = false,
    List<Vehicle>? vehicles,
    List<MonthlyPass>? passes,
    List<MonthlyPassPayment>? pending,
  }) async {
    repository = FakeMonthlyPassRepository()..listError = listError;
    if (passes != null) {
      repository.passes = passes;
    }
    if (pending != null) {
      repository.pending = pending;
    }
    final branding = BrandingCubit(
      FakeParkingSettingsRepository(
        ParkingSettings(whatsappAuto: whatsappAuto),
      ),
    );
    addTearDown(branding.close);
    await branding.load();
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<MonthlyPassesCubit>(
              create: (_) => MonthlyPassesCubit(
                repository,
                FakeVehicleRepository(
                  vehicles ??
                      [
                        Vehicle(
                          id: 1,
                          plate: 'ABC123',
                          categoryId: 1,
                          ownerPhone: ownerPhone,
                        ),
                      ],
                ),
              ),
            ),
            BlocProvider<BrandingCubit>.value(value: branding),
          ],
          child: const MonthlyPassesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders passes with plates, es_CO dates and COP', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Mensualidades'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('1/1/2026 – 31/1/2026 · \$100.000'), findsOneWidget);
    // The sample pass ended in January, so it is shown as expired.
    expect(find.text('Vencida'), findsOneWidget);
  });

  testWidgets('Failure: a failed toggle keeps the list and shows a SnackBar', (
    tester,
  ) async {
    await pumpPage(tester);
    repository.writeError = const ValidationFailure('Pass expired');

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Pass expired'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('Success: deactivation can be undone', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repository.updates.map((u) => u.active), [false, true]);
  });

  testWidgets(
    'Security: delete asks for confirmation before calling the cubit',
    (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Eliminar mensualidad de ABC123'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);

      await tester.tap(find.byTooltip('Eliminar mensualidad de ABC123'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(repository.deleted, [1]);
    },
  );

  testWidgets('Failure: create requires dates and a positive amount', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Agregar mensualidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    expect(find.text('Ingresa un valor mayor a 0'), findsOneWidget);
    expect(repository.created, isNull);
  });

  testWidgets('Failure: load error shows retry', (tester) async {
    await pumpPage(tester, listError: const NetworkFailure());
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('A11y: tooltips, 48dp targets and contrast', (tester) async {
    await pumpPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('Success: a pass with a customer phone offers the WhatsApp notice',
      (tester) async {
    await pumpPage(tester, ownerPhone: '+57 300 111 2233');

    expect(find.byTooltip('Avisar por WhatsApp'), findsOneWidget);
  });

  testWidgets('Security: no phone means no WhatsApp action', (tester) async {
    await pumpPage(tester);

    expect(find.byTooltip('Avisar por WhatsApp'), findsNothing);
  });

  testWidgets('Success: automated mode queues the reminder instead of wa.me',
      (tester) async {
    final messages = FakeCustomerMessageRepository();
    serviceLocator.registerSingleton<CustomerMessageRepository>(messages);
    addTearDown(serviceLocator.reset);

    await pumpPage(
      tester,
      ownerPhone: '+57 300 111 2233',
      whatsappAuto: true,
    );

    await tester.tap(find.byTooltip('Avisar por WhatsApp'));
    await tester.pumpAndSettle();

    expect(messages.sent, hasLength(1));
    expect(messages.sent.single.template, 'pass_expiry');
    expect(messages.sent.single.params.first, 'ABC123');
    expect(find.text('Mensaje en cola de WhatsApp'), findsOneWidget);
  });

  testWidgets('Success: the plate search narrows the passes', (tester) async {
    await pumpPage(
      tester,
      vehicles: const [
        Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
        Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
      ],
      passes: [
        samplePass,
        MonthlyPass(
          id: 2,
          vehicleId: 2,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 31),
          amount: 100000,
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsNothing);
    expect(find.text('XYZ999'), findsOneWidget);
  });

  testWidgets('Failure: a search with no matches explains itself', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'QQQ');
    await tester.pumpAndSettle();

    expect(
      find.text('Ninguna mensualidad coincide con «QQQ»'),
      findsOneWidget,
    );
  });

  testWidgets('Success: collecting a pending payment is confirmed', (
    tester,
  ) async {
    await pumpPage(tester, pending: [samplePayment]);

    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Pago de mensualidad registrado'), findsOneWidget);
    expect(repository.paid, [7]);
  });

  testWidgets('Success: an expiring pass can be renewed in place', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Renovar 30 días'), findsOneWidget);
    await tester.tap(find.text('Renovar 30 días'));
    await tester.pumpAndSettle();
    expect(find.text('¿Renovar la mensualidad?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Renovar 30 días'));
    await tester.pumpAndSettle();

    final update = repository.updates.single;
    expect(update.startDate, isNotNull);
    expect(update.endDate!.difference(update.startDate!).inDays, 29);
    expect(find.text('Mensualidad renovada 30 días'), findsOneWidget);
  });
}
