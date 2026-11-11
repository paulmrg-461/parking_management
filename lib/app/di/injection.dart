import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/lot/lot_context.dart';
import '../../core/network/resilient_http_client.dart';
import '../../core/storage/secure_supabase_storage.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/infrastructure/auth_local_data_source.dart';
import 'auth_state_sync.dart';
import 'modules/audit_module.dart';
import 'modules/auth_module.dart';
import 'modules/categories_module.dart';
import 'modules/check_in_module.dart';
import 'modules/check_out_module.dart';
import 'modules/core_module.dart';
import 'modules/customer_messages_module.dart';
import 'modules/lots_module.dart';
import 'modules/monthly_passes_module.dart';
import 'modules/notifications_module.dart';
import 'modules/observability_module.dart';
import 'modules/plate_scanning_module.dart';
import 'modules/platform_module.dart';
import 'modules/receipt_printing_module.dart';
import 'modules/reports_module.dart';
import 'modules/evidence_module.dart';
import 'modules/policies_module.dart';
import 'modules/public_booking_module.dart';
import 'modules/waitlist_module.dart';
import 'modules/records_module.dart';
import 'modules/reservations_module.dart';
import 'modules/spots_module.dart';
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
  // Hive must know its path before anything opens a box: the Supabase boot
  // below clears a stale cached session, which reads `auth` through Hive.
  await serviceLocator<KeyValueStore>().init();
  await _initSupabase(config);
}

/// Boots GoTrue and keeps the cached bearer token fresh: Supabase rotates
/// access tokens in the background, so the Hive snapshot is rewritten; a
/// GoTrue sign-out of a live session surfaces as an expired session.
Future<void> _initSupabase(AppConfig config) async {
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    httpClient: ResilientHttpClient(http.Client()),
    authOptions: FlutterAuthClientOptions(
      // Keychain/Keystore on mobile. On the web `flutter_secure_storage`
      // needs a secure context (HTTPS or localhost): over plain HTTP on the
      // LAN its WebCrypto calls are unavailable and the login hangs, so the
      // browser falls back to gotrue's localStorage store.
      localStorage: kIsWeb ? null : SecureSupabaseStorage(),
    ),
  );
  serviceLocator.registerSingleton<SupabaseClient>(supabase.client);
  // This build sends row versions on table writes, so a lot that turns on
  // `row_version_required` keeps working. Set before the lot header so both
  // survive the map rebuild below.
  supabase.client.headers = {
    ...supabase.client.headers,
    'x-versioned-write': '1',
  };
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
  final authSync = AuthStateSync(
    serviceLocator<AuthLocalDataSource>(),
    () => serviceLocator<AuthCubit>().sessionExpired(),
  );
  supabase.client.auth.onAuthStateChange.listen(authSync.handle);
}

/// Registers every module into [sl] without touching storage (testable).
void registerAllModules(GetIt sl, AppConfig config) {
  registerCoreModule(sl, config);
  registerCustomerMessagesModule(sl);
  registerPlatformModule(sl);
  registerAuthModule(sl);
  registerAuditModule(sl);
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
  registerObservabilityModule(sl);
  registerReportsModule(sl);
  registerReservationsModule(sl);
  registerRecordsModule(sl);
  registerPoliciesModule(sl);
  registerEvidenceModule(sl);
  registerPublicBookingModule(sl);
  registerWaitlistModule(sl);
  registerSpotsModule(sl);
  registerSettingsModule(sl);
  registerShiftsModule(sl);
  registerSyncModule(sl);
}
