import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin abstraction over ML Kit's [TextRecognizer] so [MlKitPlateScanner] can
/// be unit-tested with a fake implementation instead of the real platform
/// channel.
abstract class TextRecognizerClient {
  Future<RecognizedText> processImage(InputImage image);
}

/// Production [TextRecognizerClient] backed by the real ML Kit
/// [TextRecognizer] (Latin script).
class MlKitTextRecognizerClient implements TextRecognizerClient {
  MlKitTextRecognizerClient()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<RecognizedText> processImage(InputImage image) =>
      _recognizer.processImage(image);
}
