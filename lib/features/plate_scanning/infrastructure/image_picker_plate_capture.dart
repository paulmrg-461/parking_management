import 'package:image_picker/image_picker.dart';

import '../domain/repositories/plate_image_capture.dart';

/// Captures a still image from the device camera using `image_picker`'s
/// one-shot capture, compressed on capture so evidence uploads stay well
/// under the backend's 5 MB per-photo limit.
class ImagePickerPlateCapture implements PlateImageCapture {
  ImagePickerPlateCapture([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  static const imageQuality = 80;
  static const maxDimension = 1920.0;

  final ImagePicker _picker;

  @override
  Future<XFile?> capture() => _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: imageQuality,
    maxWidth: maxDimension,
    maxHeight: maxDimension,
  );
}
