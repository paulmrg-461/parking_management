import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_destinations.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_icon_button.dart';
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
                    DashboardLoaded(:final openSessions) => MergeSemantics(
                      child: Column(
                        key: const ValueKey('loaded'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$openSessions',
                            style: textTheme.displaySmall,
                          ),
                          Text(l10n.homeOccupancy, style: textTheme.bodyLarge),
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
