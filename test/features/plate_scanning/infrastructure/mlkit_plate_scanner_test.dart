import 'dart:ui';

import 'package:cross_file/cross_file.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/mlkit_plate_scanner.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/text_recognizer_client.dart';

class _FakeTextRecognizer implements TextRecognizerClient {
  _FakeTextRecognizer(this._response);

  _FakeTextRecognizer.throwing() : _response = null, _throws = true;

  final RecognizedText? _response;
  bool _throws = false;

  @override
  Future<RecognizedText> processImage(InputImage image) async {
    if (_throws) {
      throw Exception('platform channel unavailable');
    }
    return _response!;
  }
}

TextBlock _blockOf(String text) => TextBlock(
  text: text,
  lines: const [],
  boundingBox: Rect.zero,
  recognizedLanguages: const [],
  cornerPoints: const [],
);

void main() {
  final image = XFile('scan.jpg');

  test(
    'Success: extracts the most plate-like block with a confidence score',
    () async {
      final recognized = RecognizedText(
        text: 'PARKING\nABC123',
        blocks: [_blockOf('PARKING'), _blockOf('abc 123')],
      );
      final scanner = MlKitPlateScanner(_FakeTextRecognizer(recognized));

      final result = await scanner.scan(image);

      expect(result.candidatePlate, 'ABC123');
      expect(result.confidence, greaterThan(0));
    },
  );

  test('Success: ML Kit scanning is supported on mobile', () {
    expect(
      MlKitPlateScanner(_FakeTextRecognizer.throwing()).isSupported,
      isTrue,
    );
  });

  test(
    'Failure: wraps an OCR processing error as a ValidationFailure',
    () async {
      final scanner = MlKitPlateScanner(_FakeTextRecognizer.throwing());

      expect(scanner.scan(image), throwsA(isA<ValidationFailure>()));
    },
  );

  test('Security: rejects garbage/injection-like text instead of returning it as a plate', () async {
    final recognized = RecognizedText(
      text: "'; DROP TABLE vehicles; --",
      blocks: [_blockOf("'; DROP TABLE vehicles; --"), _blockOf('AEIOU')],
    );
    final scanner = MlKitPlateScanner(_FakeTextRecognizer(recognized));

    final result = await scanner.scan(image);

    expect(result.candidatePlate, isEmpty);
    expect(result.confidence, 0.0);
  });
}
