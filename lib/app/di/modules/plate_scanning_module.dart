import 'package:get_it/get_it.dart';

import '../../../features/plate_scanning/application/plate_scanning_cubit.dart';
import '../../../features/plate_scanning/domain/repositories/plate_scanner.dart';

/// The scanner/camera adapters themselves come from the platform module.
void registerPlateScanningModule(GetIt sl) {
  sl.registerFactory<PlateScanningCubit>(
    () => PlateScanningCubit(sl<PlateScanner>()),
  );
}
