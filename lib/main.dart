import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/di/hive_registrar.g.dart';
import 'app/di/injection.dart';
import 'core/l10n/l10n.dart';
import 'core/network/connectivity_cubit.dart';
import 'core/sync/sync_service.dart';
import 'core/sync/sync_status_cubit.dart';
import 'features/auth/application/auth_cubit.dart';
import 'features/settings/application/branding_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean deep links on web (`/check-in`, not `/#/check-in`); no-op elsewhere.
  usePathUrlStrategy();
  await initializeDateFormatting(formatLocale);
  Hive.registerAdapters();
  await configureDependencies();
  final authCubit = serviceLocator<AuthCubit>();
  // Restore the token BEFORE the outbox drains: otherwise a cold start with
  // queued work would fire token-less requests and stop on 401.
  await authCubit.restore();
  serviceLocator<SyncService>().start();
  final syncStatus = serviceLocator<SyncStatusCubit>();
  unawaited(syncStatus.load());
  final connectivity = serviceLocator<ConnectivityCubit>();
  unawaited(connectivity.start());
  runApp(
    ParkingApp(
      authCubit: authCubit,
      syncStatusCubit: syncStatus,
      brandingCubit: serviceLocator<BrandingCubit>(),
      connectivityCubit: connectivity,
    ),
  );
}
