import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/network/connectivity_cubit.dart';
import '../core/sync/sync_status_cubit.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/search_shortcuts.dart';
import '../features/auth/application/auth_cubit.dart';
import '../features/lots/application/lots_cubit.dart';
import '../features/settings/application/branding_cubit.dart';
import 'router/app_router.dart';
import 'router/go_router_refresh_stream.dart';

/// Root widget. Owns the router and its auth refresh listenable so both are
/// created once and disposed with the app (no global router singleton).
class ParkingApp extends StatefulWidget {
  const ParkingApp({
    super.key,
    required this.authCubit,
    required this.syncStatusCubit,
    required this.brandingCubit,
    this.connectivityCubit,
    this.lotsCubit,
  });

  final AuthCubit authCubit;
  final SyncStatusCubit syncStatusCubit;
  final BrandingCubit brandingCubit;

  /// Multi-lot context; optional so single-lot tests can omit it.
  final LotsCubit? lotsCubit;

  /// Drives the offline banner; optional so tests can omit it.
  final ConnectivityCubit? connectivityCubit;

  @override
  State<ParkingApp> createState() => _ParkingAppState();
}

class _ParkingAppState extends State<ParkingApp> {
  late final GoRouterRefreshStream _refresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _refresh = GoRouterRefreshStream(widget.authCubit.stream);
    _router = buildRouter(widget.authCubit, _refresh);
    // Seed from Hive, then refresh: a no-network first run just stays put.
    unawaited(widget.brandingCubit.load());
    if (widget.lotsCubit case final lots?) {
      unawaited(lots.load());
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: widget.authCubit),
        BlocProvider<SyncStatusCubit>.value(value: widget.syncStatusCubit),
        BlocProvider<BrandingCubit>.value(value: widget.brandingCubit),
        if (widget.lotsCubit case final lots?)
          BlocProvider<LotsCubit>.value(value: lots),
        if (widget.connectivityCubit case final connectivity?)
          BlocProvider<ConnectivityCubit>.value(value: connectivity),
      ],
      child: SearchShortcuts(
        child: MaterialApp.router(
          onGenerateTitle: (context) =>
              context.read<BrandingCubit>().state.titleFor(context.l10n),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          locale: defaultLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        ),
      ),
    );
  }
}
