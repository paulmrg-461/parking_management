import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/shell/app_destinations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/elapsed.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/plate_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/application/auth_cubit.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../check_out/domain/entities/capacity_snapshot.dart';
import '../../../check_out/domain/entities/dashboard_trend.dart';
import '../../../check_out/domain/entities/lot_setup_status.dart';
import '../../../shifts/application/shift_cubit.dart';
import '../../application/dashboard_cubit.dart';

class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.homeGreeting(name),
            style: textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          '$role · ${Formatters.date(DateTime.now())}',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Occupancy KPI: the number, the configured spots and a bar. Failures stay
/// inline so the actions keep working offline.
class OccupancyCard extends StatelessWidget {
  const OccupancyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _KpiIcon(icon: Icons.local_parking_rounded),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(l10n.homeOccupancy, style: textTheme.titleSmall),
                ),
                AppIconButton(
                  icon: Icons.refresh,
                  tooltip: l10n.homeRefreshTooltip,
                  onPressed: context.read<DashboardCubit>().load,
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) => AnimatedSwitcher(
                duration: Motion.short,
                child: switch (state) {
                  DashboardLoading() => const LinearProgressIndicator(),
                  DashboardLoaded(
                    :final openSessions,
                    :final totalCapacity,
                    :final capacity,
                  ) =>
                    _OccupancySummary(
                      openSessions: openSessions,
                      totalCapacity: totalCapacity,
                      capacity: capacity,
                    ),
                  DashboardFailure(:final failure) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeOccupancyUnavailable,
                        style: textTheme.titleMedium,
                      ),
                      Text(l10n.failure(failure), style: textTheme.bodySmall),
                    ],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted circle used as the leading icon of the home KPI cards.
class _KpiIcon extends StatelessWidget {
  const _KpiIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
    );
  }
}

/// Big occupancy number. When the site configured group spaces (cars+pickups,
/// motorcycles) the number counts those real spots only; trucks and buses are
/// not limited and stay out of the fraction.
class _OccupancySummary extends StatelessWidget {
  const _OccupancySummary({
    required this.openSessions,
    required this.totalCapacity,
    required this.capacity,
  });

  final int openSessions;
  final int totalCapacity;
  final CapacitySnapshot capacity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    var occupied = 0;
    var places = 0;
    var outOfService = 0;
    if (capacity.carCapacity > 0) {
      occupied += capacity.carOpen;
      places += capacity.carAvailable;
      outOfService += capacity.carOutOfService;
    }
    if (capacity.motoCapacity > 0) {
      occupied += capacity.motoOpen;
      places += capacity.motoAvailable;
      outOfService += capacity.motoOutOfService;
    }
    final hasGroups = capacity.carCapacity > 0 || capacity.motoCapacity > 0;
    final open = hasGroups ? occupied : openSessions;
    final total = hasGroups ? places : totalCapacity;
    final full = hasGroups
        ? total == 0 || occupied >= total
        : total > 0 && open >= total;
    final fraction = total > 0 ? (open / total).clamp(0.0, 1.0) : 0.0;
    return MergeSemantics(
      child: Row(
        key: const ValueKey('loaded'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large text settings shrink the big figure instead of
                // overflowing next to the radial gauge.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        total > 0 ? '$open / $total' : '$open',
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (full) ...[
                        const SizedBox(width: Space.sm),
                        StatusChip(
                          label: l10n.homeFull,
                          tone: StatusTone.warning,
                        ),
                      ],
                    ],
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(height: Space.sm),
                  _OccupancyBar(fraction: fraction),
                ],
                if (outOfService > 0) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.capacityOutOfService(outOfService),
                    style: textTheme.labelSmall?.copyWith(
                      color: textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: Space.md),
            _OccupancyGauge(fraction: fraction, full: full),
          ],
        ],
      ),
    );
  }
}

/// Radial occupancy: the same fraction as the bar, readable at a glance from
/// across the cabin. The percentage is painted as text too, so the state never
/// depends on color alone.
class _OccupancyGauge extends StatelessWidget {
  const _OccupancyGauge({required this.fraction, required this.full});

  final double fraction;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final color = full ? theme.colorScheme.error : status.success;
    final percent = (fraction * 100).round();
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '$percent%',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills the occupancy bar, animating the change unless the platform asks for
/// reduced motion.
class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return LinearProgressIndicator(value: fraction);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: Motion.short,
      builder: (context, value, _) => LinearProgressIndicator(value: value),
    );
  }
}

/// Space configuration vs. what is inside: cars + pickups, motorcycles and
/// cars that left their keys. `0` appears as "no limit" with no bar.
class CapacityCard extends StatelessWidget {
  const CapacityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is! DashboardLoaded) {
          return const SizedBox.shrink();
        }
        final capacity = state.capacity;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _KpiIcon(icon: Icons.speed_outlined),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l10n.homeCapacityTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                _CapacityRow(
                  icon: Icons.directions_car_outlined,
                  label: l10n.homeCapacityCars,
                  open: capacity.carOpen,
                  reserved: capacity.carReserved,
                  capacity: capacity.carCapacity,
                  available: capacity.carAvailable,
                  outOfService: capacity.carOutOfService,
                  full: capacity.carsFull,
                ),
                _CapacityRow(
                  icon: Icons.two_wheeler_outlined,
                  label: l10n.homeCapacityMotos,
                  open: capacity.motoOpen,
                  reserved: capacity.motoReserved,
                  capacity: capacity.motoCapacity,
                  available: capacity.motoAvailable,
                  outOfService: capacity.motoOutOfService,
                  full: capacity.motosFull,
                ),
                _CapacityRow(
                  icon: Icons.key_outlined,
                  label: l10n.homeCapacityKeys,
                  open: capacity.keysOpen,
                  capacity: capacity.keyCapacity,
                  available: capacity.keyCapacity,
                  full: capacity.keysFull,
                ),
                if (capacity.reservationsActive > 0) ...[
                  const Divider(height: Space.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.homeReservationsActive(
                            capacity.reservationsActive,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/reservations'),
                        child: Text(l10n.homeSeeReservations),
                      ),
                    ],
                  ),
                  if (capacity.reservationsExpiring > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        l10n.homeReservationsExpiring(
                          capacity.reservationsExpiring,
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({
    required this.icon,
    required this.label,
    required this.open,
    required this.capacity,
    required this.available,
    required this.full,
    this.reserved = 0,
    this.outOfService = 0,
  });

  final IconData icon;
  final String label;
  final int open;
  final int reserved;

  /// Configured spots (`0` = no limit) and how many of them are usable.
  final int capacity;
  final int available;
  final int outOfService;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final limited = capacity > 0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  limited
                      ? '$open / $available'
                      : '$open · ${l10n.homeNoLimit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: full ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (limited) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: available <= 0 ? 1 : (open / available).clamp(0, 1),
              color: full ? scheme.error : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ],
          if (outOfService > 0) ...[
            const SizedBox(height: 2),
            Text(
              l10n.capacityOutOfService(outOfService),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (reserved > 0) ...[
            const SizedBox(height: 2),
            Text(
              l10n.homeReservedCount(reserved),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// First cars still inside, with a shortcut to the full check-out list.
class InsideCard extends StatelessWidget {
  const InsideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is! DashboardLoaded) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _KpiIcon(icon: Icons.garage_outlined),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l10n.openSessionsTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/check-out'),
                      child: Text(l10n.homeInsideSeeAll),
                    ),
                  ],
                ),
                if (state.sessions.isEmpty)
                  Text(l10n.openSessionsEmpty, style: theme.textTheme.bodySmall)
                else
                  for (var i = 0; i < state.sessions.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      // Straight to the charge dialog, like the slot board.
                      onTap: () => context.go(
                        '/check-out?scan=${Uri.encodeQueryComponent(state.plateOf(state.sessions[i]))}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.directions_car,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                state.plateOf(state.sessions[i]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PlateText.styleFor(
                                  context,
                                  PlateSize.medium,
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            Text(
                              elapsedLabel(l10n, state.sessions[i].entryTime),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (state.sessions[i].hasPass) ...[
                              const SizedBox(width: Space.sm),
                              StatusChip(
                                label: l10n.paymentMonthlyPass,
                                tone: StatusTone.success,
                                icon: Icons.card_membership,
                              ),
                            ],
                            if (state.sessions[i].leftKeys) ...[
                              const SizedBox(width: Space.xs),
                              Icon(
                                Icons.key_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                                semanticLabel: l10n.checkInLeftKeysShort,
                              ),
                            ],
                            if (state.sessions[i].photoCount > 0) ...[
                              const SizedBox(width: Space.xs),
                              Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                                semanticLabel: l10n.sessionPhotos(
                                  state.sessions[i].photoCount,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The two operator actions: large, color-coded and always above the KPIs so
/// the main job is the first thing on screen.
class PrimaryActions extends StatelessWidget {
  const PrimaryActions({
    super.key,
    required this.onEntry,
    required this.onExit,
  });

  final VoidCallback onEntry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _BigAction(
              icon: Icons.login,
              label: l10n.navCheckIn,
              hint: l10n.homeEntryHint,
              onPressed: onEntry,
              primary: true,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: _BigAction(
              icon: Icons.logout,
              label: l10n.navCheckOut,
              hint: l10n.homeExitHint,
              onPressed: onExit,
              primary: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = primary ? scheme.primary : scheme.secondaryContainer;
    final foreground = primary ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Semantics(
      button: true,
      label: '$label. $hint',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 26, color: foreground),
                const SizedBox(height: Space.sm),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: foreground.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin summary: a two-column grid of section tiles.
class ManagementShortcuts extends StatelessWidget {
  const ManagementShortcuts({super.key, required this.destinations});

  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.homeManagement, style: textTheme.titleMedium),
        ),
        const SizedBox(height: Space.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - Space.sm) / 2;
            return Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final destination in destinations)
                  SizedBox(
                    width: tileWidth,
                    child: _ShortcutTile(destination: destination),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = destination.label(l10n);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => context.go(destination.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(destination.icon, size: 20, color: scheme.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
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
    );
  }
}

/// Compact shift state on Home: open/close from the cash screen.
class ShiftCard extends StatelessWidget {
  const ShiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftCubit? cubit;
    try {
      cubit = context.watch<ShiftCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = cubit.state;
    final shift = state.current;
    final unavailable = state.status == ShiftStatus.failure;
    final open = shift != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => context.go('/shift'),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _KpiIcon(icon: open ? Icons.point_of_sale : Icons.lock_open),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      unavailable
                          ? l10n.shiftUnavailable
                          : open
                          ? l10n.shiftOpenTitle
                          : l10n.shiftNoOpen,
                      style: textTheme.titleSmall,
                    ),
                  ),
                  if (open)
                    StatusChip(
                      label: l10n.statusOpen,
                      tone: StatusTone.success,
                    ),
                  const SizedBox(width: Space.xs),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                unavailable
                    ? l10n.errorUnknown
                    : open
                    ? '${l10n.shiftExpectedCash}: '
                          '${Formatters.money(shift.expectedCash)} · '
                          '${l10n.shiftSessions}: ${shift.sessionCount}'
                    : l10n.homeShift,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's revenue and traffic for the active site. Renders nothing until the
/// dashboard state is loaded (the occupancy card already shows the spinner).
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<DashboardCubit, DashboardState>(
      buildWhen: (previous, current) =>
          previous is DashboardLoaded != current is DashboardLoaded ||
          (previous is DashboardLoaded &&
              current is DashboardLoaded &&
              previous.today != current.today),
      builder: (context, state) {
        if (state is! DashboardLoaded) {
          return const SizedBox.shrink();
        }
        final today = state.today;
        final quiet =
            today.revenue == 0 &&
            today.entries == 0 &&
            today.exits == 0 &&
            today.passRevenue == 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _KpiIcon(icon: Icons.today_outlined),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l10n.homeToday,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                AnimatedSwitcher(
                  duration: Motion.short,
                  child: quiet
                      ? Text(
                          l10n.homeTodayEmpty,
                          key: const ValueKey('quiet'),
                          style: textTheme.bodyMedium,
                        )
                      : Column(
                          key: const ValueKey('data'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MoneyText(
                              today.revenue,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: Space.sm),
                            Wrap(
                              spacing: Space.lg,
                              runSpacing: Space.xs,
                              children: [
                                _TodayMetric(
                                  label: l10n.homeTodayEntries,
                                  value: '${today.entries}',
                                ),
                                _TodayMetric(
                                  label: l10n.homeTodayExits,
                                  value: '${today.exits}',
                                ),
                                _TodayMetric(
                                  label: l10n.homeTodayCash,
                                  value: Formatters.money(today.cashRevenue),
                                ),
                                if (today.passRevenue > 0)
                                  _TodayMetric(
                                    label: l10n.homeTodayPasses,
                                    value: Formatters.money(today.passRevenue),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: textTheme.titleSmall),
      ],
    );
  }
}

/// Seven-day activity for the site: one bar per business day, the weekly
/// totals below and (for admins) a shortcut to the full reports screen.
/// Operators see it too: it is a summary, not an admin-only report.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<DashboardCubit, DashboardState>(
      buildWhen: (previous, current) =>
          previous is! DashboardLoaded ||
          current is! DashboardLoaded ||
          previous.trend != current.trend,
      builder: (context, state) {
        final loading = state is DashboardLoading;
        final failed = state is DashboardFailure;
        final trend = state is DashboardLoaded
            ? state.trend
            : DashboardTrend.empty;
        final current = trend.latest(7);
        final previous = trend.window(7, skip: 7);
        final quiet =
            state is DashboardLoaded && !current.any((day) => day.hasMovement);
        final previousTotal = trend.revenueOf(previous);
        final currentTotal = trend.revenueOf(current);
        final comparable =
            previous.length == current.length &&
            current.isNotEmpty &&
            previousTotal > 0;
        final delta = comparable
            ? ((currentTotal - previousTotal) * 100 / previousTotal).round()
            : null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _KpiIcon(icon: Icons.show_chart),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.homeTrend, style: textTheme.titleSmall),
                          Text(
                            current.isEmpty
                                ? l10n.homeTrendHint
                                : _rangeLabel(context, current),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isAdmin(context))
                      AppIconButton(
                        icon: Icons.open_in_new,
                        tooltip: l10n.homeTrendOpenReports,
                        onPressed: () => context.go('/reports'),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (loading)
                  const _TrendSkeleton()
                else if (failed)
                  _TrendQuiet(message: l10n.homeTrendUnavailable)
                else if (quiet)
                  _TrendQuiet(message: l10n.homeTrendEmpty)
                else ...[
                  _TrendChart(days: current),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.lg,
                    runSpacing: Space.xs,
                    children: [
                      _TodayMetric(
                        label: l10n.homeTrendTotal,
                        value: Formatters.money(currentTotal),
                      ),
                      _TodayMetric(
                        label: l10n.homeTrendEntries,
                        value: '${_sum(current, (day) => day.entries)}',
                      ),
                      _TodayMetric(
                        label: l10n.homeTrendExits,
                        value: '${_sum(current, (day) => day.exits)}',
                      ),
                    ],
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: Space.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: delta == 0
                            ? l10n.homeTrendFlat
                            : l10n.homeTrendVsPrevious(_signedPercent(delta)),
                        tone: switch (delta) {
                          > 0 => StatusTone.success,
                          < 0 => StatusTone.warning,
                          _ => StatusTone.neutral,
                        },
                        icon: switch (delta) {
                          > 0 => Icons.trending_up,
                          < 0 => Icons.trending_down,
                          _ => Icons.trending_flat,
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static int _sum(List<TrendDay> days, int Function(TrendDay) value) =>
      days.fold<int>(0, (total, day) => total + value(day));

  static String _signedPercent(int percent) =>
      percent > 0 ? '+$percent %' : '$percent %';

  static String _rangeLabel(BuildContext context, List<TrendDay> days) {
    final format = DateFormat.MMMd(context.l10n.localeName);
    return context.l10n.homeTrendRange(
      format.format(days.first.date),
      format.format(days.last.date),
    );
  }
}

/// Bars scaled to the best day of the range; zero days keep a thin baseline
/// so the series stays readable.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.days});

  final List<TrendDay> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(
      0,
      (max, day) => day.revenue > max ? day.revenue : max,
    );
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: _TrendBar(
                day: days[i],
                peak: peak,
                isToday: i == days.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.day,
    required this.peak,
    required this.isToday,
  });

  final TrendDay day;
  final int peak;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = DateFormat.MMMd(l10n.localeName).format(day.date);
    final semantic = l10n.homeTrendDay(
      label,
      Formatters.money(day.revenue),
      day.entries,
      day.exits,
    );
    final ratio = peak <= 0 ? 0.0 : day.revenue / peak;
    Widget bar() {
      if (day.revenue == 0) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        );
      }
      return FractionallySizedBox(
        heightFactor: ratio.clamp(0.08, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: isToday ? scheme.tertiary : scheme.primary,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      );
    }

    return Tooltip(
      message: semantic,
      child: Semantics(
        label: semantic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(alignment: Alignment.bottomCenter, child: bar()),
              ),
              const SizedBox(height: Space.xs),
              Text(
                DateFormat.d(l10n.localeName).format(day.date),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder with the same geometry as the chart while the dashboard loads.
class _TrendSkeleton extends StatelessWidget {
  const _TrendSkeleton();

  static const _heights = [0.4, 0.7, 0.55, 0.9, 0.35, 0.8, 0.6];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final factor in _heights)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: Space.xs,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: factor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendQuiet extends StatelessWidget {
  const _TrendQuiet({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.insights_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Admin-only onboarding card: shows the missing setup steps of a new site
/// and links to the screen that fixes each one. Hidden once the site is ready
/// or when the status RPC failed.
class SetupChecklistCard extends StatelessWidget {
  const SetupChecklistCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    if (!_isAdmin(context)) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<DashboardCubit, DashboardState>(
      buildWhen: (previous, current) =>
          previous is! DashboardLoaded ||
          current is! DashboardLoaded ||
          previous.setup != current.setup,
      builder: (context, state) {
        final setup = state is DashboardLoaded
            ? state.setup
            : LotSetupStatus.unknown;
        if (!setup.known || setup.complete) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const _KpiIcon(icon: Icons.checklist_outlined),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.setupTitle, style: textTheme.titleSmall),
                            Text(
                              l10n.setupProgress(
                                setup.doneSteps,
                                LotSetupStatus.totalSteps,
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  LinearProgressIndicator(
                    value: setup.doneSteps / LotSetupStatus.totalSteps,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  const SizedBox(height: Space.xs),
                  _SetupStep(
                    done: setup.hasCategories,
                    title: l10n.setupCategories,
                    hint: l10n.setupCategoriesHint,
                    onTap: () => context.go('/categories'),
                  ),
                  _SetupStep(
                    done: setup.hasTariffs,
                    title: l10n.setupTariffs,
                    hint: l10n.setupTariffsHint,
                    onTap: () => context.go('/tariffs'),
                  ),
                  _SetupStep(
                    done: setup.hasCapacity,
                    title: l10n.setupCapacity,
                    hint: l10n.setupCapacityHint,
                    onTap: () => context.go('/settings'),
                  ),
                  _SetupStep(
                    done: setup.hasIdentity,
                    title: l10n.setupIdentity,
                    hint: l10n.setupIdentityHint,
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.done,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = done
        ? StatusColors.of(context).success
        : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Layout.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: color,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(
                      hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!done)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isAdmin(BuildContext context) {
  try {
    final auth = context.read<AuthCubit>();
    return switch (auth.state) {
      AuthAuthenticated(:final session) => session.user.role == UserRole.admin,
      _ => false,
    };
  } on ProviderNotFoundException {
    return false;
  }
}
