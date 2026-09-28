import 'package:cross_file/cross_file.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/plate_scan_result.dart';
import '../domain/repositories/plate_scanner.dart';
import 'text_recognizer_client.dart';

/// [PlateScanner] adapter backed by Google ML Kit on-device OCR.
///
/// Picks the most plate-like recognized text block (alphanumeric, length
/// 4-10, not a vowels-only run) and assigns it a heuristic confidence based
/// on how close its length is to a typical plate length. When no block looks
/// like a plate, an empty candidate is returned so the caller can fall back
/// to manual entry.
class MlKitPlateScanner implements PlateScanner {
  MlKitPlateScanner([TextRecognizerClient? client])
    : _client = client ?? MlKitTextRecognizerClient();

  final TextRecognizerClient _client;

  static final RegExp _plateLikePattern = RegExp(r'^[A-Z0-9]{4,10}$');
  static final RegExp _vowelsOnlyPattern = RegExp(r'^[AEIOU]+$');
  static const _typicalPlateLength = 6;

  @override
  bool get isSupported => true;

  @override
  Future<PlateScanResult> scan(XFile image) async {
    final recognizedText = await _recognize(image);
    final candidate = _mostPlateLikeText(recognizedText.blocks);
    return PlateScanResult(
      rawText: recognizedText.text,
      candidatePlate: candidate ?? '',
      confidence: candidate == null ? 0.0 : _confidenceOf(candidate),
    );
  }

  Future<RecognizedText> _recognize(XFile image) async {
    try {
      return await _client.processImage(InputImage.fromFilePath(image.path));
    } catch (_) {
      throw const ValidationFailure(
        'Could not read text from image',
        ClientFailureCodes.ocrNoText,
      );
    }
  }

  String? _mostPlateLikeText(List<TextBlock> blocks) {
    final candidates = blocks
        .map((block) => _sanitize(block.text))
        .where(_isPlateLike);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.reduce((a, b) => _rank(a) >= _rank(b) ? a : b);
  }

  String _sanitize(String text) =>
      text.replaceAll(RegExp(r'\s'), '').toUpperCase();

  bool _isPlateLike(String text) =>
      _plateLikePattern.hasMatch(text) && !_vowelsOnlyPattern.hasMatch(text);

  int _rank(String text) =>
      _typicalPlateLength - (text.length - _typicalPlateLength).abs();

  double _confidenceOf(String text) =>
      (_rank(text) / _typicalPlateLength).clamp(0.3, 0.95);
}
