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
    this.size = 120,
    this.foreground = Colors.black,
    this.background = Colors.white,
    this.semanticLabel,
  });

  final String data;
  final double size;
  final Color foreground;
  final Color background;
  final String? semanticLabel;

  /// White margin around the modules (the QR spec asks for ~4 modules; the
  /// modules are ~5 px at the default size).
  static const _quietZone = 12.0;

  @override
  Widget build(BuildContext context) {
    // Generate for the inner square only: painting it into the padded canvas
    // keeps every module (an outer-sized matrix used to clip the last rows).
    final inner = size - _quietZone * 2;
    final bars = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    ).make(data, width: inner, height: inner).whereType<BarcodeBar>().where(
      (bar) => bar.black,
    ).toList();

    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(_quietZone),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _QrPainter(bars: bars, foreground: foreground),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.bars, required this.foreground});

  final List<BarcodeBar> bars;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = foreground;
    for (final bar in bars) {
      // The extra half pixel closes anti-aliasing seams between modules.
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width + 0.5,
          bar.height + 0.5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.bars != bars || oldDelegate.foreground != foreground;
}
