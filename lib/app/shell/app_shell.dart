import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/offline_banner.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';
import 'app_destinations.dart';

/// Responsive chrome around every authenticated page: a [NavigationBar]
/// below [wideBreakpoint] and a [NavigationRail] above it, with
/// destinations filtered by role. Content is capped at [maxContentWidth];
/// an [OfflineBanner] sits above it while the device is offline.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  static const wideBreakpoint = Layout.railBreakpoint;
  static const maxContentWidth = Layout.maxContent;

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthCubit, UserRole?>(
      (cubit) => switch (cubit.state) {
        AuthAuthenticated(:final session) => session.user.role,
        _ => null,
      },
    );
    if (role == null) {
      return child;
    }
    final content = Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              key: const Key('app-shell-content'),
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= wideBreakpoint
          ? _WideShell(role: role, location: location, content: content)
          : _NarrowShell(role: role, location: location, content: content),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.role,
    required this.location,
    required this.content,
  });

  final UserRole role;
  final String location;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(role);
    final selected = destinations.indexWhere((d) => d.matches(location));
    return Scaffold(
      body: Row(
        children: [
          _ScrollableRail(
            destinations: destinations,
            selectedIndex: selected < 0 ? null : selected,
            onSelected: (i) => context.go(destinations[i].path),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              labelType: NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label(context.l10n)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell({
    required this.role,
    required this.location,
    required this.content,
  });

  final UserRole role;
  final String location;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final primary = destinationsFor(role, management: false);
    final more = destinationsFor(role).skip(primary.length).toList();
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(primary, more),
        onDestinationSelected: (i) => i < primary.length
            ? context.go(primary[i].path)
            : _showMore(context, more),
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(context.l10n),
            ),
          if (more.isNotEmpty)
            NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              label: context.l10n.navMore,
              tooltip: context.l10n.navMoreTooltip,
            ),
        ],
      ),
    );
  }

  int _selectedIndex(List<AppDestination> primary, List<AppDestination> more) {
    final index = primary.indexWhere((d) => d.matches(location));
    if (index >= 0) {
      return index;
    }
    return more.any((d) => d.matches(location)) ? primary.length : 0;
  }

  void _showMore(BuildContext context, List<AppDestination> more) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final d in more)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label(context.l10n)),
                selected: d.matches(location),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}
