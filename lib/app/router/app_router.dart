import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/qr/qr_decoder.dart';
import '../../core/receipt/evidence_link.dart';
import '../../features/reservations/domain/repositories/reservation_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../core/widgets/deferred_page.dart';
import '../../features/audit/application/audit_cubit.dart';
import '../../features/audit/presentation/audit_page.dart';
import '../../features/diagnostics/application/diagnostics_cubit.dart';
import '../../features/diagnostics/presentation/diagnostics_page.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/check_in/application/check_in_cubit.dart';
import '../../features/check_in/application/vehicle_lookup_cubit.dart';
import '../../features/check_in/presentation/check_in_page.dart';
import '../../features/check_out/application/check_out_cubit.dart';
import '../../features/check_out/presentation/check_out_page.dart';
import '../../features/about/presentation/about_developer_page.dart';
import '../../features/evidence/application/evidence_cubit.dart';
import '../../features/evidence/presentation/public_evidence_page.dart';
import '../../features/policies/application/policies_cubit.dart';
import '../../features/policies/presentation/policies_page.dart';
import '../../features/records/application/records_cubit.dart';
import '../../features/records/presentation/records_page.dart';
import '../../features/home/application/dashboard_cubit.dart';
import '../../features/lots/application/lots_cubit.dart';
import '../../features/lots/presentation/lots_page.dart';
import '../../features/notifications/application/notifications_cubit.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/shifts/application/shift_cubit.dart';
import '../../features/shifts/presentation/shift_page.dart';
import '../../features/vehicle_history/application/vehicle_history_cubit.dart';
import '../../features/vehicle_history/presentation/vehicle_history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/plate_scanning/application/plate_scanning_cubit.dart';
import '../../features/plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../features/plate_scanning/domain/repositories/plate_scanner.dart';
import '../../features/plate_scanning/presentation/plate_scan_page.dart';
import '../../features/reservations/application/reservations_cubit.dart';
import '../../features/reservations/presentation/reservations_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import 'deferred/categories_entry.dart' deferred as categories;
import 'deferred/contact_entry.dart' deferred as contact;
import 'deferred/monthly_passes_entry.dart' deferred as monthly_passes;
import 'deferred/reports_entry.dart' deferred as reports;
import 'deferred/settings_entry.dart' deferred as settings;
import 'deferred/spots_entry.dart' deferred as spots;
import 'deferred/tariffs_entry.dart' deferred as tariffs;
import 'deferred/users_entry.dart' deferred as users;
import 'deferred/vehicles_entry.dart' deferred as vehicles;
import 'route_access.dart';
import 'route_error_page.dart';

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
  errorBuilder: (context, state) => RouteErrorPage(error: state.error),
  routes: [
    GoRoute(path: loginPath, builder: (context, state) => const LoginPage()),
    GoRoute(
      path: aboutPath,
      builder: (context, state) => const AboutDeveloperPage(),
    ),
    GoRoute(
      path: policiesPath,
      builder: (context, state) => BlocProvider<PoliciesCubit>(
        create: (_) => serviceLocator<PoliciesCubit>(),
        child: PoliciesPage(
          lotId: int.tryParse(state.uri.queryParameters['lot'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: evidencePath,
      builder: (context, state) => BlocProvider<EvidenceCubit>(
        create: (_) => serviceLocator<EvidenceCubit>(),
        child: PublicEvidencePage(
          sessionId: int.tryParse(state.uri.queryParameters['session'] ?? ''),
          plate: state.uri.queryParameters['plate'],
        ),
      ),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => BlocProvider<PlateScanningCubit>(
        create: (_) => serviceLocator<PlateScanningCubit>(),
        child: PlateScanPage(capture: serviceLocator<PlateImageCapture>()),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => BlocProvider<NotificationsCubit>(
        create: (_) {
          final cubit = serviceLocator<NotificationsCubit>();
          final session = switch (auth.state) {
            AuthAuthenticated(:final session) => session,
            _ => null,
          };
          unawaited(cubit.start(session?.user.id));
          return cubit;
        },
        child: BlocProvider<ShiftCubit>(
          create: (_) {
            final cubit = serviceLocator<ShiftCubit>();
            final isAdmin = switch (auth.state) {
              AuthAuthenticated(:final session) =>
                session.user.role == UserRole.admin,
              _ => false,
            };
            unawaited(cubit.load(admin: isAdmin));
            return cubit;
          },
          child: BlocProvider<DashboardCubit>(
            create: (_) => serviceLocator<DashboardCubit>(),
            child: AppShell(location: state.uri.path, child: child),
          ),
        ),
      ),
      routes: [_homeRoute(auth)],
    ),
  ],
);

GoRoute _homeRoute(AuthCubit auth) => GoRoute(
  path: homePath,
  builder: (context, state) => HomePage(
    reservations: serviceLocator.isRegistered<ReservationRepository>()
        ? serviceLocator<ReservationRepository>()
        : null,
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
          initialPlate: state.uri.queryParameters['plate'],
          reservations: serviceLocator<ReservationRepository>(),
          vehicles: serviceLocator<VehicleRepository>(),
        ),
      ),
    ),
    GoRoute(
      path: 'check-out',
      builder: (context, state) => BlocProvider<CheckOutCubit>(
        create: (_) => serviceLocator<CheckOutCubit>(),
        child: CheckOutPage(
          initialQuery: state.uri.queryParameters['plate'],
          scanPlate: state.uri.queryParameters['scan'],
          capture: serviceLocator<PlateImageCapture>(),
          qrDecoder: serviceLocator<QrDecoder>(),
        ),
      ),
    ),
    GoRoute(
      path: 'diagnostics',
      builder: (context, state) => BlocProvider<DiagnosticsCubit>(
        create: (_) => serviceLocator<DiagnosticsCubit>(),
        child: const DiagnosticsPage(),
      ),
    ),
    GoRoute(
      path: 'audit',
      builder: (context, state) => BlocProvider<AuditCubit>(
        create: (_) => serviceLocator<AuditCubit>(),
        child: const AuditPage(),
      ),
    ),
    GoRoute(
      path: 'lots',
      builder: (context, state) => BlocProvider<LotsCubit>.value(
        value: serviceLocator<LotsCubit>(),
        child: const LotsPage(),
      ),
    ),
    GoRoute(
      path: 'reservations',
      builder: (context, state) => BlocProvider<ReservationsCubit>(
        create: (_) => serviceLocator<ReservationsCubit>(),
        child: const ReservationsPage(),
      ),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: 'shift',
      builder: (context, state) {
        final isAdmin = switch (auth.state) {
          AuthAuthenticated(:final session) =>
            session.user.role == UserRole.admin,
          _ => false,
        };
        return ShiftPage(isAdmin: isAdmin);
      },
    ),
    GoRoute(
      path: 'records',
      builder: (context, state) => BlocProvider<RecordsCubit>(
        create: (_) => serviceLocator<RecordsCubit>(),
        child: const RecordsPage(),
      ),
    ),
    GoRoute(
      path: 'history',
      builder: (context, state) => BlocProvider<VehicleHistoryCubit>(
        create: (_) => serviceLocator<VehicleHistoryCubit>(),
        child: VehicleHistoryPage(
          initialPlate: state.uri.queryParameters['plate'],
        ),
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
    _deferred(
      'settings',
      settings.loadLibrary,
      () => settings.buildSettingsEntry(),
    ),
    _deferred(
      'spots',
      spots.loadLibrary,
      () => spots.buildSpotsEntry(
        isAdmin: switch (auth.state) {
          AuthAuthenticated(:final session) =>
            session.user.role == UserRole.admin,
          _ => false,
        },
      ),
    ),
    _deferred(
      'contact',
      contact.loadLibrary,
      () => contact.buildContactEntry(),
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
