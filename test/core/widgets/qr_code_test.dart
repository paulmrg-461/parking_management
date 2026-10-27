import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/qr/qr_decoder.dart';
import 'package:parking_management/core/widgets/qr_code.dart';

void main() {
  testWidgets('Success: the rendered QR is scannable (no clipped modules)', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const QrCode(data: 'ABC123'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return const ZxingQrDecoder().decode(bytes!.buffer.asUint8List());
    });

    expect(text, 'ABC123');
  });

  testWidgets('Failure: an empty payload never crashes the ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: QrCode(data: ''))),
    );

    expect(find.byType(QrCode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
