import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/widgets/app_icon_button.dart';
import 'package:parking_management/core/widgets/async_view.dart';
import 'package:parking_management/core/widgets/confirm_dialog.dart';
import 'package:parking_management/core/widgets/date_time_text.dart';
import 'package:parking_management/core/widgets/money_text.dart';
import 'package:parking_management/core/widgets/photo_strip.dart';
import 'package:parking_management/core/widgets/photo_thumb.dart';
import 'package:parking_management/core/widgets/plate_input_field.dart';
import 'package:parking_management/core/widgets/plate_text.dart';
import 'package:parking_management/core/widgets/status_chip.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_png.dart';

Future<void> pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(testApp(Scaffold(body: Center(child: child))));

void main() {
  group('Atoms', () {
    testWidgets('MoneyText formats COP with es_CO grouping', (tester) async {
      await pump(tester, const MoneyText(150000));
      expect(find.text('\$150.000'), findsOneWidget);
    });

    testWidgets('DateTimeText formats day/month/year and 24h time', (
      tester,
    ) async {
      await pump(tester, DateTimeText(DateTime(2026, 9, 5, 14, 7)));
      expect(find.textContaining('5/9/2026'), findsOneWidget);
      expect(find.textContaining('14:07'), findsOneWidget);
    });

    testWidgets('PlateText uses tabular monospace figures', (tester) async {
      await pump(tester, const PlateText('ABC123'));
      final text = tester.widget<Text>(find.text('ABC123'));
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('StatusChip renders its label', (tester) async {
      await pump(
        tester,
        const StatusChip(label: 'Pendiente', tone: StatusTone.pending),
      );
      expect(find.text('Pendiente'), findsOneWidget);
    });

    testWidgets('A11y: AppIconButton exposes its tooltip and is 48dp', (
      tester,
    ) async {
      await pump(
        tester,
        AppIconButton(icon: Icons.add, tooltip: 'Agregar', onPressed: () {}),
      );
      expect(find.byTooltip('Agregar'), findsOneWidget);
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('Molecules', () {
    testWidgets('PlateInputField normalizes to uppercase without spaces', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(tester, PlateInputField(controller: controller));

      await tester.enterText(find.byType(TextField), 'abc 12 3');

      expect(controller.text, 'ABC123');
    });

    testWidgets('PlateInputField shows the camera suffix only with onScan', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(tester, PlateInputField(controller: controller));
      expect(find.byTooltip('Escanear placa con la cámara'), findsNothing);

      var scans = 0;
      await pump(
        tester,
        PlateInputField(controller: controller, onScan: () => scans++),
      );
      await tester.tap(find.byTooltip('Escanear placa con la cámara'));
      expect(scans, 1);
    });

    testWidgets('A11y: PhotoThumb remove button is 48dp with tooltip', (
      tester,
    ) async {
      var removed = 0;
      await pump(
        tester,
        PhotoThumb(bytes: testPng, index: 1, onRemove: () => removed++),
      );
      final button = find.byTooltip('Quitar foto');
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(removed, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('PhotoStrip disables add at the limit and says so', (
      tester,
    ) async {
      await pump(
        tester,
        PhotoStrip(
          photos: [testPng, testPng],
          max: 2,
          onAdd: () {},
          onRemove: (_) {},
        ),
      );
      expect(find.text('Fotos de evidencia (2/2)'), findsOneWidget);
      expect(find.text('Máximo 2 fotos por entrada'), findsOneWidget);
      final add = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(add.onPressed, isNull);
    });

    testWidgets('ConfirmDialog resolves true on confirm, false on cancel', (
      tester,
    ) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ConfirmDialog.show(
              context,
              const ConfirmDialog(
                title: '¿Eliminar?',
                body: 'No se puede deshacer',
                confirmLabel: 'Eliminar',
                destructive: true,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('AsyncView', () {
    Widget view(AsyncStatus<List<String>> status) => AsyncView<List<String>>(
      status: status,
      builder: (items) => Text(items.join(',')),
    );

    testWidgets('Success: renders data', (tester) async {
      await pump(tester, view(const AsyncReady(['a', 'b'])));
      await tester.pumpAndSettle();
      expect(find.text('a,b'), findsOneWidget);
    });

    testWidgets('Empty: renders the empty message', (tester) async {
      await pump(tester, view(const AsyncEmpty('Nada por aquí')));
      await tester.pumpAndSettle();
      expect(find.text('Nada por aquí'), findsOneWidget);
    });

    testWidgets('Failure: shows error with a working retry', (tester) async {
      var retries = 0;
      await pump(tester, view(AsyncFailed('Sin conexión', () => retries++)));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);
    });

    testWidgets('Loading: shows a labelled progress indicator', (tester) async {
      await pump(tester, view(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    });
  });
}
