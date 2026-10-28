import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_destinations.dart';
import '../../../core/l10n/l10n.dart';
import '../../reservations/domain/repositories/reservation_repository.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../auth/domain/entities/user.dart';
import '../../lots/presentation/lot_switcher.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../settings/application/branding_cubit.dart';
import '../application/dashboard_cubit.dart';
import 'widgets/dashboard_widgets.dart';
import 'widgets/slot_board_card.dart';

/// Dashboard at `/`: greeting, current occupancy and the two primary
/// operator actions (Entrada / Salida). Admins also get management
/// shortcuts (the rail / menu drawer stays the main way in).
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.reservations});

  /// Admins may release holds from the space board; optional in tests.
  final ReservationRepository? reservations;

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
          // Wide screens already show the brand in the sidebar header.
          MediaQuery.sizeOf(context).width >= Layout.railBreakpoint
              ? l10n.navHome
              : context.select<BrandingCubit, String>(
                  (c) => c.state.titleFor(l10n),
                ),
        ),
        actions: const [
          NotificationBell(),
          SyncBadge(),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated(:final session) => _Dashboard(
            session: session,
            reservations: widget.reservations,
          ),
          _ => Center(
            child: CircularProgressIndicator(semanticsLabel: l10n.loading),
          ),
        },
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.session, this.reservations});

  final AuthSession session;
  final ReservationRepository? reservations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = session.user;
    final management = destinationsFor(user.role)
        .where(managementDestinations.contains)
        .toList();
    final split = MediaQuery.sizeOf(context).width >= Layout.homeSplit;
    final list = RefreshIndicator(
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
          PrimaryActions(
            onEntry: () => context.go('/check-in'),
            onExit: () => context.go('/check-out'),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.bolt_outlined,
            title: l10n.homeQuickActions,
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.history,
                  label: l10n.navRecords,
                  onTap: () => context.go('/records'),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _QuickAction(
                  icon: Icons.point_of_sale,
                  label: l10n.homeShift,
                  onTap: () => context.go('/shift'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.insights_outlined,
            title: l10n.homeSummary,
            subtitle: l10n.homeSummaryHint,
          ),
          const SizedBox(height: Space.sm),
          const _SummaryGrid(
            cards: [OccupancyCard(), CapacityCard(), TodayCard(), ShiftCard()],
          ),
          const SizedBox(height: Space.md),
          SlotBoardCard(reservations: reservations),
          const SizedBox(height: Space.md),
          if (!split) const InsideCard(),
          // The sidebar already lists every management section on desktop.
          if (management.isNotEmpty &&
              MediaQuery.sizeOf(context).width < Layout.railBreakpoint) ...[
            const SizedBox(height: Space.xl),
            ManagementShortcuts(destinations: management),
          ],
        ],
      ),
    );
    if (!split) {
      return list;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: list),
        const SizedBox(
          width: 340,
          child: Padding(
            padding: EdgeInsets.only(
              top: Space.md,
              right: Space.md,
              bottom: Space.md,
            ),
            child: SingleChildScrollView(child: InsideCard()),
          ),
        ),
      ],
    );
  }
}

/// Two KPI columns on wide content, one on phones; equal-height rows so the
/// cards line up.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: Space.md),
                cards[i],
              ],
            ],
          );
        }
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: Space.md),
                  Expanded(child: cards[1]),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: Space.md),
                  Expanded(child: cards[3]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


/// Compact secondary shortcut (records, shift): a tonal icon and a label on a
/// bordered surface, with a 48 dp minimum target.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Layout.minTouch),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
