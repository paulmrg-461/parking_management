import 'package:get_it/get_it.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/key_value_store.dart';
import 'modules/auth_module.dart';
import 'modules/categories_module.dart';
import 'modules/check_in_module.dart';
import 'modules/check_out_module.dart';
import 'modules/core_module.dart';
import 'modules/monthly_passes_module.dart';
import 'modules/plate_scanning_module.dart';
import 'modules/platform_module.dart';
import 'modules/receipt_printing_module.dart';
import 'modules/reports_module.dart';
import 'modules/settings_module.dart';
import 'modules/sync_module.dart';
import 'modules/tariffs_module.dart';
import 'modules/users_module.dart';
import 'modules/vehicles_module.dart';

final GetIt serviceLocator = GetIt.instance;

/// Composition root: every registration is lazy, so module order only
/// matters for readability. Platform-specific adapters (camera, OCR,
/// pending-photo storage) come from [registerPlatformModule], resolved per
/// platform through a conditional import.
Future<void> configureDependencies() async {
  registerAllModules(serviceLocator, AppConfig.fromEnvironment());
  await serviceLocator<KeyValueStore>().init();
}

/// Registers every module into [sl] without touching storage (testable).
void registerAllModules(GetIt sl, AppConfig config) {
  registerCoreModule(sl, config);
  registerPlatformModule(sl);
  registerAuthModule(sl);
  registerUsersModule(sl);
  registerCategoriesModule(sl);
  registerTariffsModule(sl);
  registerVehiclesModule(sl);
  registerPlateScanningModule(sl);
  registerReceiptPrintingModule(sl);
  registerCheckInModule(sl);
  registerCheckOutModule(sl);
  registerMonthlyPassesModule(sl);
  registerReportsModule(sl);
  registerSettingsModule(sl);
  registerSyncModule(sl);
}
