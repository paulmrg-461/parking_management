import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/lot/lot_context.dart';
import '../../core/storage/secure_supabase_storage.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/infrastructure/auth_local_data_source.dart';
import 'modules/auth_module.dart';
import 'modules/categories_module.dart';
import 'modules/check_in_module.dart';
import 'modules/check_out_module.dart';
import 'modules/core_module.dart';
import 'modules/lots_module.dart';
import 'modules/monthly_passes_module.dart';
import 'modules/notifications_module.dart';
import 'modules/plate_scanning_module.dart';
import 'modules/platform_module.dart';
import 'modules/receipt_printing_module.dart';
import 'modules/reports_module.dart';
import 'modules/reservations_module.dart';
import 'modules/settings_module.dart';
import 'modules/shifts_module.dart';
import 'modules/sync_module.dart';
import 'modules/tariffs_module.dart';
import 'modules/users_module.dart';
import 'modules/vehicle_history_module.dart';
import 'modules/vehicles_module.dart';

final GetIt serviceLocator = GetIt.instance;

/// Composition root: every registration is lazy, so module order only
/// matters for readability. Platform-specific adapters (camera, OCR,
/// pending-photo storage) come from [registerPlatformModule], resolved per
/// platform through a conditional import.
Future<void> configureDependencies() async {
  final config = AppConfig.fromEnvironment();
  if (!config.supabaseAuthEnabled) {
    throw StateError(
      'Supabase is required: pass --dart-define=SUPABASE_URL=... '
      'and --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  registerAllModules(serviceLocator, config);
  await _initSupabase(config);
  await serviceLocator<KeyValueStore>().init();
}

/// Boots GoTrue and keeps the cached bearer token fresh: Supabase rotates
/// access tokens in the background, so the Hive snapshot is rewritten.
Future<void> _initSupabase(AppConfig config) async {
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSupabaseStorage(),
    ),
  );
  serviceLocator.registerSingleton<SupabaseClient>(supabase.client);
  // The active lot travels as a header on every request; the client validates
  // membership server-side, so a stale value only fails closed.
  final lotContext = serviceLocator<LotContext>();
  lotContext.onApplied((lotId) {
    final headers = {...supabase.client.headers};
    if (lotId == null) {
      headers.remove('x-lot-id');
    } else {
      headers['x-lot-id'] = '$lotId';
    }
    supabase.client.headers = headers;
  });
  lotContext.restore();
  // Hive and the SDK must agree on whether there is a session; a stale Hive
  // token without an SDK session would make every query unauthenticated.
  if (supabase.client.auth.currentSession == null) {
    await serviceLocator<AuthLocalDataSource>().clearSession();
  }
  supabase.client.auth.onAuthStateChange.listen((state) async {
    final session = state.session;
    if (session == null) {
      return;
    }
    final local = serviceLocator<AuthLocalDataSource>();
    final current = await local.readSession();
    if (current == null) {
      return;
    }
    await local.saveSession(
      AuthSession(user: current.user, token: session.accessToken),
    );
  });
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
  registerVehicleHistoryModule(sl);
  registerPlateScanningModule(sl);
  registerReceiptPrintingModule(sl);
  registerCheckInModule(sl);
  registerCheckOutModule(sl);
  registerLotsModule(sl);
  registerMonthlyPassesModule(sl);
  registerNotificationsModule(sl);
  registerReportsModule(sl);
  registerReservationsModule(sl);
  registerSettingsModule(sl);
  registerShiftsModule(sl);
  registerSyncModule(sl);
}
