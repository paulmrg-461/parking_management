import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_destinations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_chip.dart';
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
        Text(role, style: textTheme.bodyMedium),
      ],
    );
  }
}

/// Big occupancy number with a refresh button; failures stay inline so the
/// primary actions below keep working offline.
class OccupancyCard extends StatelessWidget {
  const OccupancyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Icon(
              Icons.local_parking_rounded,
              size: Space.xl,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) => AnimatedSwitcher(
                  duration: Motion.short,
                  child: switch (state) {
                    DashboardLoading() => const LinearProgressIndicator(),
                    DashboardLoaded(
                      :final openSessions,
                      :final totalCapacity,
                      :final isFull,
                      :final categories,
                    ) =>
                      MergeSemantics(
                        child: Column(
                          key: const ValueKey('loaded'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  totalCapacity > 0
                                      ? '$openSessions / $totalCapacity'
                                      : '$openSessions',
                                  style: textTheme.displaySmall,
                                ),
                                if (isFull) ...[
                                  const SizedBox(width: Space.sm),
                                  StatusChip(
                                    label: l10n.homeFull,
                                    tone: StatusTone.warning,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              l10n.homeOccupancy,
                              style: textTheme.bodyLarge,
                            ),
                            if (totalCapacity > 0) ...[
                              const SizedBox(height: Space.xs),
                              _OccupancyBar(
                                fraction: (openSessions / totalCapacity).clamp(
                                  0,
                                  1,
                                ),
                              ),
                            ],
                            if (categories.any((c) => c.isFull)) ...[
                              const SizedBox(height: Space.xs),
                              Text(
                                l10n.homeFullCategories(
                                  categories
                                      .where((c) => c.isFull)
                                      .map((c) => c.name)
                                      .join(', '),
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
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
            ),
            AppIconButton(
              icon: Icons.refresh,
              tooltip: l10n.homeRefreshTooltip,
              onPressed: context.read<DashboardCubit>().load,
            ),
          ],
        ),
      ),
    );
  }
}

/// The two operator actions, large and side by side.
class PrimaryActions extends StatelessWidget {
  const PrimaryActions({super.key, required this.onEntry, required this.onExit});

  final VoidCallback onEntry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _BigAction(
            icon: Icons.login,
            label: l10n.navCheckIn,
            hint: l10n.homeEntryHint,
            onPressed: onEntry,
            tonal: false,
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: _BigAction(
            icon: Icons.logout,
            label: l10n.navCheckOut,
            hint: l10n.homeExitHint,
            onPressed: onExit,
            tonal: true,
          ),
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
    required this.tonal,
  });

  static const _height = 128.0;

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final foreground = tonal ? scheme.onSecondaryContainer : scheme.onPrimary;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(_height),
      padding: const EdgeInsets.all(Space.md),
    );
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Space.xl),
        const SizedBox(height: Space.sm),
        Text(label, style: textTheme.titleLarge?.copyWith(color: foreground)),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: foreground),
        ),
      ],
    );
    return tonal
        ? FilledButton.tonal(onPressed: onPressed, style: style, child: child)
        : FilledButton(onPressed: onPressed, style: style, child: child);
  }
}

/// Admin summary: one tile per management section.
class ManagementShortcuts extends StatelessWidget {
  const ManagementShortcuts({super.key, required this.destinations});

  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.homeManagement,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in destinations)
              ActionChip(
                avatar: Icon(d.icon),
                label: Text(d.label(l10n)),
                onPressed: () => context.go(d.path),
              ),
          ],
        ),
      ],
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
    final state = cubit.state;
    final shift = state.current;
    final unavailable = state.status == ShiftStatus.failure;
    return Card(
      child: ListTile(
        onTap: () => context.go('/shift'),
        leading: Icon(
          shift == null ? Icons.lock_open : Icons.point_of_sale,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          unavailable
              ? l10n.shiftUnavailable
              : shift == null
              ? l10n.shiftNoOpen
              : l10n.shiftOpenTitle,
        ),
        subtitle: unavailable
            ? Text(l10n.errorUnknown)
            : shift == null
            ? Text(l10n.homeShift)
            : Text(
                '${l10n.shiftExpectedCash}: '
                '${Formatters.money(shift.expectedCash)} · '
                '${l10n.shiftSessions}: ${shift.sessionCount}',
              ),
        trailing: const Icon(Icons.chevron_right),
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
                Text(l10n.homeToday, style: textTheme.labelLarge),
                const SizedBox(height: Space.xs),
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
                              style: textTheme.headlineMedium,
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
        Text(label, style: textTheme.labelSmall),
        Text(value, style: textTheme.titleSmall),
      ],
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
