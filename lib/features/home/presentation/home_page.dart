import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_destinations.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/widgets/theme_mode_button.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../auth/domain/entities/user.dart';
import '../../lots/presentation/lot_switcher.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../settings/application/branding_cubit.dart';
import '../application/dashboard_cubit.dart';
import 'widgets/dashboard_widgets.dart';

/// Dashboard at `/`: greeting, current occupancy and the two primary
/// operator actions (Entrada / Salida). Admins also get management
/// shortcuts (the rail / "Más" menu stays the main way in).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

bool _hasThemeCubit(BuildContext context) {
  try {
    context.read<ThemeCubit>();
    return true;
  } on ProviderNotFoundException {
    // Isolated tests may not provide the appearance cubit.
    return false;
  }
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<DashboardCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          // Wide screens already show the brand in the sidebar header.
          MediaQuery.sizeOf(context).width >= Layout.railBreakpoint
              ? l10n.navHome
              : context.select<BrandingCubit, String>(
                  (c) => c.state.titleFor(l10n),
                ),
        ),
        actions: [
          const NotificationBell(),
          const SyncBadge(),
          if (_hasThemeCubit(context)) const ThemeModeButton(),
          // Wide screens sign out from the sidebar user card.
          if (MediaQuery.sizeOf(context).width < Layout.railBreakpoint)
            AppIconButton(
              icon: Icons.logout,
              tooltip: l10n.actionLogout,
              onPressed: () => context.read<AuthCubit>().logout(),
            ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated(:final session) => _Dashboard(session: session),
          _ => Center(
            child: CircularProgressIndicator(semanticsLabel: l10n.loading),
          ),
        },
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = session.user;
    final management = destinationsFor(user.role)
        .where(managementDestinations.contains)
        .toList();
    return RefreshIndicator(
      onRefresh: context.read<DashboardCubit>().load,
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Greeting(
            name: user.displayName,
            role: user.role == UserRole.admin
                ? l10n.roleAdmin
                : l10n.roleOperator,
          ),
          const SizedBox(height: Space.sm),
          // Wide screens carry the site switcher in the sidebar footer.
          if (MediaQuery.sizeOf(context).width < Layout.railBreakpoint) ...[
            const LotSwitcher(),
            const SizedBox(height: Space.md),
          ] else
            const SizedBox(height: Space.lg),
          const OccupancyCard(),
          const SizedBox(height: Space.md),
          const TodayCard(),
          const SizedBox(height: Space.md),
          const ShiftCard(),
          const SizedBox(height: Space.lg),
          PrimaryActions(
            onEntry: () => context.go('/check-in'),
            onExit: () => context.go('/check-out'),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.history),
                label: Text(l10n.navHistory),
              ),
              TextButton.icon(
                onPressed: () => context.go('/shift'),
                icon: const Icon(Icons.point_of_sale),
                label: Text(l10n.homeShift),
              ),
            ],
          ),
          // The sidebar already lists every management section on desktop.
          if (management.isNotEmpty &&
              MediaQuery.sizeOf(context).width < Layout.railBreakpoint) ...[
            const SizedBox(height: Space.xl),
            ManagementShortcuts(destinations: management),
          ],
        ],
      ),
    );
  }
}
