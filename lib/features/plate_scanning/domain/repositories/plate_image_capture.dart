import 'package:cross_file/cross_file.dart';

/// Port over the device's still-image capture (camera). Implementations
/// live in infrastructure and are injected, so widgets never construct
/// platform plugins themselves.
abstract class PlateImageCapture {
  /// Captures a still image, or returns `null` if the user cancels capture
  /// (e.g. permission denied, or the picker was dismissed).
  Future<XFile?> capture();
}
