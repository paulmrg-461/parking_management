import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:parking_management/core/qr/qr_decoder.dart';

/// Renders [data] as a QR PNG with the same barcode package used by the
/// receipts, so the test covers the real generate → scan round trip.
Uint8List _qrPng(String data, {int size = 320}) {
  final bars = Barcode.qrCode()
      .make(data, width: size.toDouble(), height: size.toDouble())
      .whereType<BarcodeBar>()
      .where((bar) => bar.black);
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (final bar in bars) {
    img.fillRect(
      image,
      x1: bar.left.floor(),
      y1: bar.top.floor(),
      x2: (bar.left + bar.width).ceil(),
      y2: (bar.top + bar.height).ceil(),
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('Success: decodes the plate printed on the receipt', () async {
    final text = await const ZxingQrDecoder().decode(_qrPng('ABC123'));

    expect(text, 'ABC123');
  });

  test('Failure: an image without a QR is not a scan', () async {
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(0, 0, 0));
    final text = await const ZxingQrDecoder().decode(
      Uint8List.fromList(img.encodePng(image)),
    );

    expect(text, isNull);
  });

  test('Security: garbage bytes never throw', () async {
    final text = await const ZxingQrDecoder().decode(
      Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(text, isNull);
  });

  test('Success: a bare plate or a URL query yields the plate', () {
    expect(plateFromQrPayload('ABC123'), 'ABC123');
    expect(plateFromQrPayload(' abc 123 '), 'ABC123');
    expect(
      plateFromQrPayload('https://app.local/check-out?plate=xyz999'),
      'XYZ999',
    );
  });

  test('Security: unrelated QR payloads are rejected', () {
    expect(plateFromQrPayload(''), isNull);
    expect(plateFromQrPayload('https://example.com/menu'), isNull);
    expect(plateFromQrPayload('https://example.com/check-out'), isNull);
    expect(plateFromQrPayload('A' * 40), isNull);
  });
}
