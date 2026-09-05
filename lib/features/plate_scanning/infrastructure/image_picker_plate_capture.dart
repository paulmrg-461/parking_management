import 'package:image_picker/image_picker.dart';

/// Abstraction over the concrete image-capture mechanism so presentation
/// widgets can be tested without invoking the real device camera.
abstract class PlateImageCapture {
  /// Captures a still image, or returns `null` if the user cancels capture
  /// (e.g. permission denied, or the picker was dismissed).
  Future<XFile?> capture();
}

/// Captures a still image from the device camera for plate scanning using
/// `image_picker`'s one-shot camera capture (no live preview).
class ImagePickerPlateCapture implements PlateImageCapture {
  ImagePickerPlateCapture([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> capture() => _picker.pickImage(source: ImageSource.camera);
}
