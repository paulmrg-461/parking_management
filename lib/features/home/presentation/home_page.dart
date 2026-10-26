import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_destinations.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../auth/domain/entities/user.dart';
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
          context.select<BrandingCubit, String>(
            (c) => c.state.titleFor(l10n),
          ),
        ),
        actions: [
          const SyncBadge(),
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
    final management = destinationsFor(
      user.role,
    ).where(managementDestinations.contains).toList();
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
          const SizedBox(height: Space.lg),
          const OccupancyCard(),
          const SizedBox(height: Space.lg),
          PrimaryActions(
            onEntry: () => context.go('/check-in'),
            onExit: () => context.go('/check-out'),
          ),
          if (management.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            ManagementShortcuts(destinations: management),
          ],
        ],
      ),
    );
  }
}
