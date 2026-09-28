import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/image_picker_plate_capture.dart';

class _FakePicker extends ImagePicker {
  _FakePicker(this._result);

  final XFile? _result;
  ImageSource? source;
  int? imageQuality;
  double? maxWidth;
  double? maxHeight;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    this.imageQuality = imageQuality;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    return _result;
  }
}

void main() {
  test(
    'Success: captures from the camera and returns the picked file',
    () async {
      final picker = _FakePicker(XFile('photo.jpg'));

      final file = await ImagePickerPlateCapture(picker).capture();

      expect(file?.path, 'photo.jpg');
      expect(picker.source, ImageSource.camera);
    },
  );

  test('Failure: a cancelled capture returns null', () async {
    expect(await ImagePickerPlateCapture(_FakePicker(null)).capture(), isNull);
  });

  test('Security: compresses to JPEG quality 80 within 1920x1920 (backend 5 MB cap)', () async {
    final picker = _FakePicker(XFile('photo.jpg'));

    await ImagePickerPlateCapture(picker).capture();

    expect(picker.imageQuality, 80);
    expect(picker.maxWidth, 1920);
    expect(picker.maxHeight, 1920);
  });
}
