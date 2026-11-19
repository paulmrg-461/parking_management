import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/qr/qr_decoder.dart';
import '../../core/receipt/evidence_link.dart';
import '../../core/receipt/feedback_link.dart';
import '../../features/public_booking/application/public_booking_cubit.dart';
import '../../features/public_booking/presentation/public_booking_page.dart';
import '../../features/reservations/domain/repositories/reservation_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../core/widgets/deferred_page.dart';
import '../../features/anomalies/application/anomalies_cubit.dart';
import '../../features/anomalies/presentation/anomalies_page.dart';
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
import '../../features/feedback/application/public_feedback_cubit.dart';
import '../../features/feedback/presentation/public_feedback_page.dart';
import '../../features/help/presentation/help_page.dart';
import '../../features/preferences/presentation/preferences_page.dart';
import '../../features/evidence/presentation/public_evidence_page.dart';
import '../../features/online_payments/application/online_payment_cubit.dart';
import '../../features/merchants/application/merchant_validation_cubit.dart';
import '../../features/merchants/presentation/public_validation_page.dart';
import '../../features/pass_renewal/application/pass_renewal_cubit.dart';
import '../../features/pricing/application/price_quote_cubit.dart';
import '../../features/loyalty/application/loyalty_status_cubit.dart';
import '../../features/lpr/application/lpr_inbox_cubit.dart';
import '../../features/lpr/presentation/gate_page.dart';
import '../../features/lpr/presentation/gate_settings_page.dart';
import '../../features/damage_comparison/application/damage_comparison_cubit.dart';
import '../../features/damage_comparison/presentation/damage_comparison_page.dart';
import '../../features/pass_renewal/presentation/pass_renewal_page.dart';
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
import '../../features/waitlist/application/public_waitlist_cubit.dart';
import '../../features/waitlist/application/waitlist_cubit.dart';
import '../../features/reservations/presentation/reservations_page.dart';
import '../di/injection.dart';
import '../shell/app_shell.dart';
import 'deferred/categories_entry.dart' deferred as categories;
import 'deferred/feedback_entry.dart' deferred as feedback;
import 'deferred/contact_entry.dart' deferred as contact;
import 'deferred/monthly_passes_entry.dart' deferred as monthly_passes;
import 'deferred/merchants_entry.dart' deferred as merchants;
import 'deferred/pricing_entry.dart' deferred as pricing;
import 'deferred/loyalty_entry.dart' deferred as loyalty;
import 'deferred/invoicing_entry.dart' deferred as invoicing;
import 'deferred/report_assistant_entry.dart' deferred as report_assistant;
import 'deferred/devices_entry.dart' deferred as devices;
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
GoRouter buildRouter(
  AuthCubit auth,
  Listenable refresh, {
  String initialLocation = homePath,
}) => GoRouter(
  initialLocation: initialLocation,
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
      path: reservePath,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<PublicBookingCubit>(
            create: (_) => serviceLocator<PublicBookingCubit>(),
          ),
          BlocProvider<PublicWaitlistCubit>(
            create: (_) => serviceLocator<PublicWaitlistCubit>(),
          ),
        ],
        child: PublicBookingPage(
          lotId: int.tryParse(state.uri.queryParameters['lot'] ?? '') ?? 1,
          waitlistCode: int.tryParse(
            state.uri.queryParameters['waitlist'] ?? '',
          ),
          captchaSiteKey: serviceLocator.isRegistered<AppConfig>()
              ? serviceLocator<AppConfig>().turnstileSiteKey
              : '',
        ),
      ),
    ),
    GoRoute(
      path: evidencePath,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<EvidenceCubit>(
            create: (_) => serviceLocator<EvidenceCubit>(),
          ),
          BlocProvider<OnlinePaymentCubit>(
            create: (_) => serviceLocator<OnlinePaymentCubit>(),
          ),
        ],
        child: PublicEvidencePage(
          sessionId: int.tryParse(state.uri.queryParameters['session'] ?? ''),
          plate: state.uri.queryParameters['plate'],
          payReference: state.uri.queryParameters['pay'],
        ),
      ),
    ),
    GoRoute(
      path: validatePath,
      builder: (context, state) => BlocProvider<MerchantValidationCubit>(
        create: (_) => serviceLocator<MerchantValidationCubit>(),
        child: PublicValidationPage(
          token: state.uri.queryParameters['m'],
        ),
      ),
    ),
    GoRoute(
      path: renewPath,
      builder: (context, state) => BlocProvider<PassRenewalCubit>(
        create: (_) => serviceLocator<PassRenewalCubit>(),
        child: PassRenewalPage(token: state.uri.queryParameters['t']),
      ),
    ),
    GoRoute(
      path: feedbackPath,
      builder: (context, state) => BlocProvider<PublicFeedbackCubit>(
        create: (_) => serviceLocator<PublicFeedbackCubit>(),
        child: PublicFeedbackPage(
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
          BlocProvider<PriceQuoteCubit>(
            create: (_) => serviceLocator<PriceQuoteCubit>(),
          ),
          if (serviceLocator.isRegistered<LoyaltyStatusCubit>())
            BlocProvider<LoyaltyStatusCubit>(
              create: (_) => serviceLocator<LoyaltyStatusCubit>(),
            ),
        ],
        child: CheckInPage(
          capture: serviceLocator<PlateImageCapture>(),
          canScan: serviceLocator<PlateScanner>().isSupported,
          initialPlate: state.uri.queryParameters['plate'],
          initialSpotId: int.tryParse(state.uri.queryParameters['spot'] ?? ''),
          reservations: serviceLocator<ReservationRepository>(),
          vehicles: serviceLocator<VehicleRepository>(),
        ),
      ),
    ),
    GoRoute(
      path: 'damage-comparison',
      builder: (context, state) {
        final sessionId = int.tryParse(
              state.uri.queryParameters['session'] ?? '',
            ) ??
            0;
        return BlocProvider<DamageComparisonCubit>(
          create: (_) =>
              serviceLocator<DamageComparisonCubit>(param1: sessionId),
          child: DamageComparisonPage(sessionId: sessionId),
        );
      },
    ),
    GoRoute(
      path: 'check-out',
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<CheckOutCubit>(
            create: (_) => serviceLocator<CheckOutCubit>(),
          ),
          if (serviceLocator.isRegistered<LoyaltyStatusCubit>())
            BlocProvider<LoyaltyStatusCubit>(
              create: (_) => serviceLocator<LoyaltyStatusCubit>(),
            ),
        ],
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
      path: 'anomalies',
      builder: (context, state) => BlocProvider<AnomaliesCubit>(
        create: (_) => serviceLocator<AnomaliesCubit>(),
        child: const AnomaliesPage(),
      ),
    ),
    GoRoute(
      path: 'audit',
      builder: (context, state) => BlocProvider<AuditCubit>(
        create: (_) => serviceLocator<AuditCubit>(),
        child: AuditPage(
          initialTable: state.uri.queryParameters['table'],
          initialSearch: state.uri.queryParameters['search'],
        ),
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
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider<ReservationsCubit>(
            create: (_) => serviceLocator<ReservationsCubit>(),
          ),
          BlocProvider<WaitlistCubit>(
            create: (_) => serviceLocator<WaitlistCubit>(),
          ),
        ],
        child: const ReservationsPage(),
      ),
    ),
    GoRoute(
      path: 'gate',
      builder: (context, state) => BlocProvider<LprInboxCubit>(
        create: (_) => serviceLocator<LprInboxCubit>(),
        child: Builder(
          builder: (context) {
            final auth = context.watch<AuthCubit>().state;
            final admin = auth is AuthAuthenticated &&
                auth.session.user.role == UserRole.admin;
            return GatePage(
              onSettings: admin ? () => context.push('/gate-settings') : null,
            );
          },
        ),
      ),
    ),
    GoRoute(
      path: 'gate-settings',
      builder: (context, state) => const GateSettingsPage(),
    ),
    GoRoute(path: 'help', builder: (context, state) => const HelpPage()),
    GoRoute(
      path: 'preferences',
      builder: (context, state) => const PreferencesPage(),
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
    _deferred(
      'merchants',
      merchants.loadLibrary,
      () => merchants.buildMerchantsEntry(),
    ),
    _deferred(
      'pricing',
      pricing.loadLibrary,
      () => pricing.buildPricingEntry(),
    ),
    _deferred(
      'loyalty',
      loyalty.loadLibrary,
      () => loyalty.buildLoyaltyEntry(),
    ),
    _deferred(
      'invoicing',
      invoicing.loadLibrary,
      () => invoicing.buildInvoicingEntry(),
    ),
    _deferred(
      'devices',
      devices.loadLibrary,
      () => devices.buildDevicesEntry(),
    ),
    _deferred(
      'report-assistant',
      report_assistant.loadLibrary,
      () => report_assistant.buildReportAssistantEntry(),
    ),
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
      'satisfaction',
      feedback.loadLibrary,
      () => feedback.buildFeedbackEntry(),
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
