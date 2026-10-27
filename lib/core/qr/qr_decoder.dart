import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code from an image. Pure Dart (zxing2 + image) so it works on
/// Android and web without another native plugin.
abstract class QrDecoder {
  /// The decoded text, or `null` when the image has no readable QR code.
  Future<String?> decode(Uint8List bytes);
}

class ZxingQrDecoder implements QrDecoder {
  const ZxingQrDecoder();

  @override
  Future<String?> decode(Uint8List bytes) => compute(_decode, bytes);
}

String? _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }
  // Phone photos are large; the QR survives a downscale and decoding gets
  // much faster.
  final image = decoded.width > 1200
      ? img.copyResize(decoded, width: 1200)
      : decoded;
  final pixels = Int32List(image.width * image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      pixels[y * image.width + x] =
          (pixel.a.toInt() << 24) |
          (pixel.r.toInt() << 16) |
          (pixel.g.toInt() << 8) |
          pixel.b.toInt();
    }
  }
  try {
    final source = RGBLuminanceSource(image.width, image.height, pixels);
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text;
  } catch (_) {
    return null;
  }
}

/// Extracts a plate from a scanned payload: a bare plate or a URL carrying
/// `plate=`/`p=` (the receipt encodes the plate itself). Anything else is
/// rejected so a random QR cannot start a check-out.
String? plateFromQrPayload(String payload) {
  final text = payload.trim();
  if (text.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final value =
        uri.queryParameters['plate'] ?? uri.queryParameters['p'] ?? '';
    return _plate(value);
  }
  return _plate(text);
}

String? _plate(String raw) {
  final normalized = raw.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '').toUpperCase();
  if (normalized.length < 3 || normalized.length > 20) {
    return null;
  }
  return normalized;
}
