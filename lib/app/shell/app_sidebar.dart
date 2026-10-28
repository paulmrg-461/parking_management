import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_cubit.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/theme/theme_cubit.dart';
import '../../core/widgets/language_button.dart';
import '../../core/widgets/theme_mode_button.dart';
import '../../core/theme/status_colors.dart';
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
  static const _managementKey = 'sidebar_management_open';

  bool _collapsed = false;
  bool _managementOpen = true;

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
    final open = serviceLocator<KeyValueStore>().get(_box, _managementKey);
    if (open is bool) {
      _managementOpen = open;
    }
  }

  Future<void> _remember(String key, bool value) async {
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    try {
      await serviceLocator<KeyValueStore>().put(_box, key, value);
    } catch (_) {
      // A layout preference is not worth an error dialog.
    }
  }

  Future<void> _toggleManagement() async {
    setState(() => _managementOpen = !_managementOpen);
    await _remember(_managementKey, _managementOpen);
  }

  Future<void> _toggle() async {
    setState(() => _collapsed = !_collapsed);
    await _remember(_key, _collapsed);
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
      clipBehavior: Clip.hardEdge,
      width: _collapsed ? Layout.sidebarCollapsed : Layout.sidebar,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerLow, scheme.surface],
        ),
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _header(context),
            Divider(
              height: 1,
              indent: _collapsed ? Space.sm : Space.md,
              endIndent: _collapsed ? Space.sm : Space.md,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: Space.xs),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: _collapsed ? Space.xs : Space.sm,
                ),
                children: [
                  ..._group(context, l10n.navGroupOperation, primary),
                  if (management.isNotEmpty) ...[
                    if (_collapsed) ...[
                      const Divider(
                        height: Space.lg,
                        indent: Space.sm,
                        endIndent: Space.sm,
                      ),
                      ..._groupItems(context, management),
                    ] else ...[
                      const SizedBox(height: Space.sm),
                      _ManagementSection(
                        label: l10n.navGroupManagement,
                        open: _managementOpen,
                        count: management.length,
                        onTap: _toggleManagement,
                        children: _accordionItems(context, management),
                      ),
                    ],
                  ],
                  const SizedBox(height: Space.md),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final session = _session(context);
    final roleLabel = session == null
        ? null
        : session.user.role == UserRole.admin
        ? l10n.roleAdmin
        : l10n.roleOperator;
    final toggle = _CollapseButton(
      collapsed: _collapsed,
      tooltip: _collapsed ? l10n.sidebarExpand : l10n.sidebarCollapse,
      onPressed: _toggle,
    );

    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          children: [
            const _BrandMark(size: 38),
            const SizedBox(height: Space.sm),
            toggle,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.xs, Space.md),
      child: Row(
        children: [
          const _BrandMark(size: 40),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                if (roleLabel != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatusDot(
                        color: session?.user.role == UserRole.admin
                            ? scheme.primary
                            : StatusColors.of(context).success,
                      ),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
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
    padding: const EdgeInsets.fromLTRB(
      Space.sm,
      Space.md,
      Space.sm,
      Space.sm,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  List<Widget> _accordionItems(
    BuildContext context,
    List<AppDestination> destinations,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.only(left: Space.sm, bottom: Space.xs),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: Space.sm),
          child: Column(
            children: [
              for (final destination in destinations)
                _SidebarItem(
                  key: ValueKey('sidebar_item_${destination.path}'),
                  destination: destination,
                  collapsed: false,
                  dense: true,
                  selected: destination.matches(widget.location),
                  onTap: () => context.go(destination.path),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _groupItems(
    BuildContext context,
    List<AppDestination> destinations,
  ) => [
    for (final destination in destinations)
      _SidebarItem(
        key: ValueKey('sidebar_item_${destination.path}'),
        destination: destination,
        collapsed: _collapsed,
        selected: destination.matches(widget.location),
        onTap: () => context.go(destination.path),
      ),
  ];

  Widget _footer(BuildContext context) {
    final l10n = context.l10n;
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
          _Preferences(collapsed: _collapsed),
          if (lots != null && lots.canSwitch && lots.active != null) ...[
            _SiteCard(
              collapsed: _collapsed,
              name: lots.active!.name,
              tooltip: l10n.lotSwitchTooltip(lots.active!.name),
              onTap: () =>
                  showLotSwitcher(context, lots.lots, lots.active!),
            ),
          ],
          if (session != null) ...[
            if (lots != null && lots.canSwitch && lots.active != null)
              const SizedBox(height: Space.sm),
            _UserCard(
              collapsed: _collapsed,
              displayName: session.user.displayName,
              roleLabel: session.user.role == UserRole.admin
                  ? l10n.roleAdmin
                  : l10n.roleOperator,
              initials: _initials(session.user.displayName),
              onLogout: () => context.read<AuthCubit>().logout(),
            ),
          ],
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

/// Language and appearance live with the account, not in the page app bar.
class _Preferences extends StatelessWidget {
  const _Preferences({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final language = _provided<LocaleCubit>(context);
    final theme = _provided<ThemeCubit>(context);
    if (!language && !theme) {
      return const SizedBox.shrink();
    }
    final buttons = [
      if (language) const LanguageButton(),
      if (theme) const ThemeModeButton(),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: collapsed
          ? Column(children: buttons)
          : Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: buttons,
            ),
    );
  }

  static bool _provided<T>(BuildContext context) {
    try {
      context.read<T>();
      return true;
    } on ProviderNotFoundException {
      return false;
    }
  }
}

/// Logo inside a tonal tile so the brand reads as an app mark, not a photo.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Image.asset(
          'assets/branding/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.local_parking_rounded,
            size: size * 0.58,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Small square button that expands/collapses the rail.
class _CollapseButton extends StatelessWidget {
  const _CollapseButton({
    required this.collapsed,
    required this.tooltip,
    required this.onPressed,
  });

  final bool collapsed;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(Layout.minTouch, Layout.minTouch),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      icon: AnimatedRotation(
        turns: collapsed ? 0.5 : 0,
        duration: Motion.short,
        child: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.destination,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final AppDestination destination;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  /// Nested management rows use a slightly tighter type scale.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = destination.label(l10n);
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(Radii.md);

    final row = Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Layout.minTouch),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.short,
                  width: selected ? 3 : 0,
                  height: 22,
                  margin: EdgeInsets.only(
                    left: collapsed ? 0 : Space.xs,
                    right: collapsed ? 0 : Space.sm,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 0 : Space.sm,
                      vertical: Space.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: collapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: dense ? 20 : 21,
                          color: foreground,
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: (dense
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.labelLarge)
                                  ?.copyWith(
                                    color: foreground,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: collapsed ? Tooltip(message: label, child: row) : row,
    );
  }
}

/// Active-site pill in the footer (becomes a tooltip-only icon when collapsed).
class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.collapsed,
    required this.name,
    required this.tooltip,
    required this.onTap,
  });

  final bool collapsed;
  final String name;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    if (collapsed) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(Icons.location_on_outlined, color: scheme.primary),
          style: IconButton.styleFrom(
            minimumSize: const Size(Layout.minTouch, Layout.minTouch),
          ),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.lotLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more,
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

/// Signed-in user card with the session actions, mirroring a web app's
/// profile block. Collapsed it keeps only the avatar and the logout button.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.collapsed,
    required this.displayName,
    required this.roleLabel,
    required this.initials,
    required this.onLogout,
  });

  final bool collapsed;
  final String displayName;
  final String roleLabel;
  final String initials;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primary,
          child: Text(
            initials,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: StatusColors.of(context).success,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surfaceContainerHigh, width: 2),
            ),
          ),
        ),
      ],
    );
    final logout = IconButton(
      tooltip: l10n.actionLogout,
      onPressed: onLogout,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(Layout.minTouch, Layout.minTouch),
        foregroundColor: scheme.onSurfaceVariant,
      ),
      icon: const Icon(Icons.logout, size: 19),
    );

    if (collapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(message: '$displayName · $roleLabel', child: avatar),
          const SizedBox(height: 2),
          logout,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.xs, Space.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          logout,
        ],
      ),
    );
  }
}

/// Collapsible "Gestión" section: a header with a rotating chevron and the
/// management destinations indented under a guide line.
class _ManagementSection extends StatelessWidget {
  const _ManagementSection({
    required this.label,
    required this.open,
    required this.count,
    required this.onTap,
    required this.children,
  });

  final String label;
  final bool open;
  final int count;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: label,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InkWell(
              key: const Key('sidebar_management_toggle'),
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Layout.minTouch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.space_dashboard_outlined,
                        size: 21,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      AnimatedRotation(
                        turns: open ? 0 : -0.25,
                        duration: Motion.short,
                        child: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.short,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Column(children: children)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
