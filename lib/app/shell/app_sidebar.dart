import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/theme/tokens.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/lots/application/lots_cubit.dart';
import '../../features/lots/presentation/lot_switcher.dart';
import '../../features/settings/application/branding_cubit.dart';
import '../di/injection.dart';
import 'app_destinations.dart';

/// Web-style side navigation: brand, role-filtered destinations in groups and
/// a footer with the active site and the signed-in user. It collapses to
/// icons (state persisted per device) to give the content more room.
class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key, required this.role, required this.location});

  final UserRole role;
  final String location;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _box = 'preferences';
  static const _key = 'sidebar_collapsed';

  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    final stored = serviceLocator<KeyValueStore>().get(_box, _key);
    if (stored == true) {
      _collapsed = true;
    }
  }

  Future<void> _toggle() async {
    setState(() => _collapsed = !_collapsed);
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    try {
      await serviceLocator<KeyValueStore>().put(_box, _key, _collapsed);
    } catch (_) {
      // A layout preference is not worth an error dialog.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final all = destinationsFor(widget.role);
    final primary = destinationsFor(widget.role, management: false);
    final primaryPaths = {for (final destination in primary) destination.path};
    final management = [
      for (final destination in all)
        if (!primaryPaths.contains(destination.path)) destination,
    ];

    return AnimatedContainer(
      duration: Motion.short,
      curve: Curves.easeOutCubic,
      width: _collapsed ? Layout.sidebarCollapsed : Layout.sidebar,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _header(context),
            const SizedBox(height: Space.sm),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: _collapsed ? Space.xs : Space.sm,
                ),
                children: [
                  ..._group(context, l10n.navGroupOperation, primary),
                  if (management.isNotEmpty) ...[
                    if (_collapsed)
                      const Divider(height: Space.lg, indent: Space.sm, endIndent: Space.sm)
                    else
                      _groupLabel(context, l10n.navGroupManagement),
                    ..._groupItems(context, management),
                  ],
                  const SizedBox(height: Space.md),
                ],
              ),
            ),
            const Divider(height: 1),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(Space.xs),
      child: Image.asset(
        'assets/branding/logo.png',
        width: 34,
        height: 34,
        errorBuilder: (_, _, _) => Icon(
          Icons.local_parking_rounded,
          size: 30,
          color: scheme.primary,
        ),
      ),
    );
    final toggle = IconButton(
      tooltip: _collapsed ? l10n.sidebarExpand : l10n.sidebarCollapse,
      onPressed: _toggle,
      icon: Icon(_collapsed ? Icons.chevron_right : Icons.chevron_left),
    );

    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Column(
          children: [
            logo,
            const SizedBox(height: Space.xs),
            toggle,
          ],
        ),
      );
    }
    final session = _session(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, 0),
      child: Row(
        children: [
          logo,
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (session != null)
                  Text(
                    session.user.role == UserRole.admin
                        ? l10n.roleAdmin
                        : l10n.roleOperator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          toggle,
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    try {
      return context.select<BrandingCubit, String>(
        (cubit) => cubit.state.titleFor(context.l10n),
      );
    } on ProviderNotFoundException {
      return context.l10n.appTitle;
    }
  }

  AuthSession? _session(BuildContext context) {
    try {
      return context.select<AuthCubit, AuthSession?>(
        (cubit) => switch (cubit.state) {
          AuthAuthenticated(:final session) => session,
          _ => null,
        },
      );
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<Widget> _group(
    BuildContext context,
    String label,
    List<AppDestination> destinations,
  ) {
    if (destinations.isEmpty) {
      return const [];
    }
    return [
      if (!_collapsed) _groupLabel(context, label),
      ..._groupItems(context, destinations),
    ];
  }

  Widget _groupLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.xs),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  List<Widget> _groupItems(
    BuildContext context,
    List<AppDestination> destinations,
  ) => [
    for (final destination in destinations)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _SidebarItem(
          key: ValueKey('sidebar_item_${destination.path}'),
          destination: destination,
          collapsed: _collapsed,
          selected: destination.matches(widget.location),
          onTap: () => context.go(destination.path),
        ),
      ),
  ];

  Widget _footer(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final session = _session(context);
    final lots = _lots(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _collapsed ? Space.xs : Space.sm,
        Space.sm,
        _collapsed ? Space.xs : Space.sm,
        Space.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lots != null && lots.canSwitch && lots.active != null)
            Tooltip(
              message: l10n.lotSwitchTooltip(lots.active!.name),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: () =>
                    showLotSwitcher(context, lots.lots, lots.active!),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _collapsed ? 0 : Space.sm,
                    vertical: Space.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: _collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                      if (!_collapsed) ...[
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            lots.active!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (session != null)
            Tooltip(
              message:
                  '${session.user.displayName} · '
                  '${session.user.role == UserRole.admin ? l10n.roleAdmin : l10n.roleOperator}',
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _collapsed ? 0 : Space.sm,
                  vertical: Space.xs,
                ),
                child: Row(
                  mainAxisAlignment: _collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        _initials(session.user.displayName),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    if (!_collapsed) ...[
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              session.user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  LotsLoaded? _lots(BuildContext context) {
    try {
      return context.select<LotsCubit, LotsLoaded?>(
        (cubit) => cubit.state is LotsLoaded ? cubit.state as LotsLoaded : null,
      );
    } on ProviderNotFoundException {
      return null;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1].substring(0, 1)
        : '';
    return '$first$second'.toUpperCase();
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.destination,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = destination.label(l10n);
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    final row = Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : Space.sm,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: foreground,
              ),
              if (!collapsed) ...[
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: collapsed ? Tooltip(message: label, child: row) : row,
    );
  }
}
