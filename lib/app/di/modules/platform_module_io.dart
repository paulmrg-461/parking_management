import 'package:get_it/get_it.dart';

import '../../../core/sync/file_pending_photo_storage.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../../../features/plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../../features/plate_scanning/domain/repositories/plate_scanner.dart';
import '../../../features/plate_scanning/infrastructure/image_picker_plate_capture.dart';
import '../../../features/plate_scanning/infrastructure/mlkit_plate_scanner.dart';

/// Android/iOS: ML Kit OCR and file-backed pending photos.
void registerPlatformModule(GetIt sl) {
  sl
    ..registerLazySingleton<PlateImageCapture>(() => ImagePickerPlateCapture())
    ..registerLazySingleton<PlateScanner>(() => MlKitPlateScanner())
    ..registerLazySingleton<PendingPhotoStorage>(FilePendingPhotoStorage.new);
}
