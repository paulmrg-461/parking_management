import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

/// Renders [data] as a QR code with the shared `barcode` package (already a
/// dependency of the PDF receipts). The receipt carries the plate so a
/// keyboard-wedge reader types it straight into the check-out search, and the
/// camera scanner in the app opens the session.
class QrCode extends StatelessWidget {
  const QrCode({
    super.key,
    required this.data,
    this.size = 104,
    this.foreground = Colors.black,
    this.background = Colors.white,
    this.semanticLabel,
  });

  final String data;
  final double size;
  final Color foreground;
  final Color background;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bars = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    ).make(data, width: size, height: size).whereType<BarcodeBar>().where(
      (bar) => bar.black,
    ).toList();

    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _QrPainter(
            bars: bars,
            foreground: foreground,
            canvasSize: size - 12,
          ),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({
    required this.bars,
    required this.foreground,
    required this.canvasSize,
  });

  final List<BarcodeBar> bars;
  final Color foreground;
  final double canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = foreground;
    final scale = size.width / canvasSize;
    for (final bar in bars) {
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left * scale,
          bar.top * scale,
          (bar.width * scale) + 0.4,
          (bar.height * scale) + 0.4,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.bars != bars || oldDelegate.foreground != foreground;
}
