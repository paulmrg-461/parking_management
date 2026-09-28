import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/network/connectivity_cubit.dart';
import '../core/sync/sync_status_cubit.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_cubit.dart';
import 'router/app_router.dart';
import 'router/go_router_refresh_stream.dart';

/// Root widget. Owns the router and its auth refresh listenable so both are
/// created once and disposed with the app (no global router singleton).
class ParkingApp extends StatefulWidget {
  const ParkingApp({
    super.key,
    required this.authCubit,
    required this.syncStatusCubit,
    this.connectivityCubit,
  });

  final AuthCubit authCubit;
  final SyncStatusCubit syncStatusCubit;

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
        if (widget.connectivityCubit case final connectivity?)
          BlocProvider<ConnectivityCubit>.value(value: connectivity),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: defaultLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }
}
