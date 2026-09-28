import 'package:get_it/get_it.dart';

import '../../../core/sync/hive_pending_photo_storage.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../../../features/plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../../features/plate_scanning/domain/repositories/plate_scanner.dart';
import '../../../features/plate_scanning/infrastructure/image_picker_plate_capture.dart';
import '../../../features/plate_scanning/infrastructure/manual_entry_plate_scanner.dart';

/// Web: no on-device OCR (manual plate entry) and photos kept as Hive bytes
/// (IndexedDB), since there is no app file system.
void registerPlatformModule(GetIt sl) {
  sl
    ..registerLazySingleton<PlateImageCapture>(() => ImagePickerPlateCapture())
    ..registerLazySingleton<PlateScanner>(ManualEntryPlateScanner.new)
    ..registerLazySingleton<PendingPhotoStorage>(HivePendingPhotoStorage.new);
}
