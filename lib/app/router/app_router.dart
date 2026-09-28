import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/deferred_page.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/check_in/application/check_in_cubit.dart';
import '../../features/check_in/application/vehicle_lookup_cubit.dart';
import '../../features/check_in/presentation/check_in_page.dart';
import '../../features/check_out/application/check_out_cubit.dart';
import '../../features/check_out/presentation/check_out_page.dart';
import '../../features/home/application/dashboard_cubit.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/plate_scanning/application/plate_scanning_cubit.dart';
import '../../features/plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../features/plate_scanning/domain/repositories/plate_scanner.dart';
import '../../features/plate_scanning/presentation/plate_scan_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import 'deferred/categories_entry.dart' deferred as categories;
import 'deferred/monthly_passes_entry.dart' deferred as monthly_passes;
import 'deferred/reports_entry.dart' deferred as reports;
import 'deferred/tariffs_entry.dart' deferred as tariffs;
import 'deferred/users_entry.dart' deferred as users;
import 'deferred/vehicles_entry.dart' deferred as vehicles;
import 'route_access.dart';

/// Builds the app router. Redirects re-run on every [AuthCubit] change via
/// [refresh] (a `GoRouterRefreshStream` owned and disposed by the caller).
///
/// Every authenticated page is nested under `/` inside the [AppShell], so
/// `go('/users')` builds the stack `[home, users]`: sub-pages get a back
/// arrow and Android back returns home instead of closing the app.
/// `/scan` lives on the root navigator (full-screen camera, returns a plate).
GoRouter buildRouter(AuthCubit auth, Listenable refresh) => GoRouter(
  initialLocation: homePath,
  refreshListenable: refresh,
  redirect: (_, state) => authRedirect(auth.state, state.uri.path),
  routes: [
    GoRoute(path: loginPath, builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/scan',
      builder: (context, state) => BlocProvider<PlateScanningCubit>(
        create: (_) => serviceLocator<PlateScanningCubit>(),
        child: PlateScanPage(capture: serviceLocator<PlateImageCapture>()),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [_homeRoute],
    ),
  ],
);

final GoRoute _homeRoute = GoRoute(
  path: homePath,
  builder: (context, state) => BlocProvider<DashboardCubit>(
    create: (_) => serviceLocator<DashboardCubit>(),
    child: const HomePage(),
  ),
  routes: [
    GoRoute(
      path: 'check-in',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<CheckInCubit>(
            create: (_) => serviceLocator<CheckInCubit>(),
          ),
          BlocProvider<VehicleLookupCubit>(
            create: (_) => serviceLocator<VehicleLookupCubit>(),
          ),
          BlocProvider<PlateScanningCubit>(
            create: (_) => serviceLocator<PlateScanningCubit>(),
          ),
        ],
        child: CheckInPage(
          capture: serviceLocator<PlateImageCapture>(),
          canScan: serviceLocator<PlateScanner>().isSupported,
        ),
      ),
    ),
    GoRoute(
      path: 'check-out',
      builder: (context, state) => BlocProvider<CheckOutCubit>(
        create: (_) => serviceLocator<CheckOutCubit>(),
        child: const CheckOutPage(),
      ),
    ),
    // Admin-only sections are deferred: operators never download them.
    _deferred('users', users.loadLibrary, () => users.buildUsersEntry()),
    _deferred(
      'categories',
      categories.loadLibrary,
      () => categories.buildCategoriesEntry(),
    ),
    _deferred(
      'tariffs',
      tariffs.loadLibrary,
      () => tariffs.buildTariffsEntry(),
    ),
    _deferred(
      'vehicles',
      vehicles.loadLibrary,
      () => vehicles.buildVehiclesEntry(),
    ),
    _deferred(
      'monthly-passes',
      monthly_passes.loadLibrary,
      () => monthly_passes.buildMonthlyPassesEntry(),
    ),
    _deferred(
      'reports',
      reports.loadLibrary,
      () => reports.buildReportsEntry(),
    ),
  ],
);

GoRoute _deferred(
  String path,
  Future<void> Function() loader,
  Widget Function() build,
) => GoRoute(
  path: path,
  builder: (context, state) =>
      DeferredPage(loader: loader, builder: (_) => build()),
);
