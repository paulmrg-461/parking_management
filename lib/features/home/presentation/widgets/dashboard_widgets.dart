import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_destinations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/elapsed.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../check_out/domain/entities/capacity_snapshot.dart';
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
                  child: Text(
                    l10n.homeOccupancy,
                    style: textTheme.titleSmall,
                  ),
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
    if (capacity.carCapacity > 0) {
      occupied += capacity.carOpen;
      places += capacity.carCapacity;
    }
    if (capacity.motoCapacity > 0) {
      occupied += capacity.motoOpen;
      places += capacity.motoCapacity;
    }
    final hasGroups = places > 0;
    final open = hasGroups ? occupied : openSessions;
    final total = hasGroups ? places : totalCapacity;
    final full = total > 0 && open >= total;
    return MergeSemantics(
      child: Column(
        key: const ValueKey('loaded'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                StatusChip(label: l10n.homeFull, tone: StatusTone.warning),
              ],
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: Space.sm),
            _OccupancyBar(fraction: (open / total).clamp(0, 1)),
          ],
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
                  capacity: capacity.carCapacity,
                  full: capacity.carsFull,
                ),
                _CapacityRow(
                  icon: Icons.two_wheeler_outlined,
                  label: l10n.homeCapacityMotos,
                  open: capacity.motoOpen,
                  capacity: capacity.motoCapacity,
                  full: capacity.motosFull,
                ),
                _CapacityRow(
                  icon: Icons.key_outlined,
                  label: l10n.homeCapacityKeys,
                  open: capacity.keysOpen,
                  capacity: capacity.keyCapacity,
                  full: capacity.keysFull,
                ),
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
    required this.full,
  });

  final IconData icon;
  final String label;
  final int open;
  final int capacity;
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
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                limited ? '$open / $capacity' : '$open · ${l10n.homeNoLimit}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: full ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (limited) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (open / capacity).clamp(0, 1),
              color: full ? scheme.error : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(Radii.pill),
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
                  Text(
                    l10n.openSessionsEmpty,
                    style: theme.textTheme.bodySmall,
                  )
                else
                  for (var i = 0; i < state.sessions.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () => context.go(
                        '/check-out?plate=${Uri.encodeQueryComponent(state.plateOf(state.sessions[i]))}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontFamily: 'monospace',
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
  const PrimaryActions({super.key, required this.onEntry, required this.onExit});

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
    final foreground = primary
        ? scheme.onPrimary
        : scheme.onSecondaryContainer;
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.85),
                  ),
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
                  _KpiIcon(
                    icon: open ? Icons.point_of_sale : Icons.lock_open,
                  ),
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
