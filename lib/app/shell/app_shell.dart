import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/realtime/local_activity.dart';
import '../di/injection.dart';
import '../../core/qr/qr_decoder.dart';
import '../../core/qr/qr_scan_page.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/submission_feedback.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/home/application/dashboard_cubit.dart';
import '../../features/lots/application/lots_cubit.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/notifications/application/notifications_cubit.dart';
import '../../features/shifts/application/shift_cubit.dart';
import '../../features/plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../features/settings/application/branding_cubit.dart';
import 'app_destinations.dart';
import 'app_sidebar.dart';

/// Responsive chrome around every authenticated page: the [NavigationBar]
/// below [wideBreakpoint] and a collapsible [AppSidebar] above it, with
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
    final content = BlocListener<LotsCubit, LotsState>(
      listenWhen: (previous, current) =>
          previous is LotsLoaded &&
          current is LotsLoaded &&
          previous.activeId != current.activeId,
      listener: (context, state) =>
          _reloadForLot(context, admin: role == UserRole.admin),
      child: BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.latestArrived?.id != current.latestArrived?.id,
      listener: (context, state) {
        final notification = state.latestArrived;
        if (notification == null) {
          return;
        }
        // Another device moved a vehicle: refetch the shell summaries. The
        // acting device already refreshed locally, so the echo is harmless.
        _reloadForLot(context, admin: role == UserRole.admin);
        if (_isOwnEcho(notification)) {
          return;
        }
        showInfoSnack(context, activityMessage(context, notification));
      },
      child: Column(
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
      ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= wideBreakpoint
          ? _WideShell(role: role, location: location, content: content)
          : _NarrowShell(role: role, location: location, content: content),
    );
  }
}

/// A realtime row for the check-in/check-out this same device just wrote is
/// already visible locally; the snackbar would be a duplicate.
bool _isOwnEcho(AppNotification notification) {
  final action = notification.data['action'];
  final sessionId = notification.data['session_id'];
  return action is String &&
      sessionId is num &&
      LocalActivity.owns(action, sessionId.toInt());
}

/// Localized text for the live activity feed; other notification types keep
/// the server body.
String activityMessage(BuildContext context, AppNotification notification) {
  final l10n = context.l10n;
  final data = notification.data;
  final actor = data['actor_name'];
  final plate = data['plate'];
  if (actor is! String || actor.isEmpty || plate is! String || plate.isEmpty) {
    return '${notification.title} · ${notification.body}';
  }
  return switch (data['action']) {
    'check_in' => l10n.activityCheckIn(actor, plate),
    'check_out' => switch (data['amount_charged']) {
      final num amount => l10n.activityCheckOut(
        actor,
        plate,
        Formatters.money(amount.toInt()),
      ),
      _ => l10n.activityCheckOutNoAmount(actor, plate),
    },
    _ => '${notification.title} · ${notification.body}',
  };
}

/// Refreshes the shell-scoped summaries after a lot switch. Providers are
/// optional so isolated tests can omit them.
void _reloadForLot(BuildContext context, {bool admin = false}) {
  try {
    unawaited(context.read<DashboardCubit>().load());
  } on ProviderNotFoundException {
    // no dashboard in this context
  }
  try {
    unawaited(context.read<ShiftCubit>().load(admin: admin));
  } on ProviderNotFoundException {
    // no shift cubit in this context
  }
  try {
    unawaited(context.read<BrandingCubit>().load());
  } on ProviderNotFoundException {
    // no branding cubit in this context
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
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(role: role, location: location),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: isManagementLocation(location)
          ? null
          : const _ScanQrFab(),
    );
  }
}

class _NarrowShell extends StatefulWidget {
  const _NarrowShell({
    required this.role,
    required this.location,
    required this.content,
  });

  final UserRole role;
  final String location;
  final Widget content;

  @override
  State<_NarrowShell> createState() => _NarrowShellState();
}

class _NarrowShellState extends State<_NarrowShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _barCount = 4;

  List<AppDestination> get _bar =>
      destinationsFor(widget.role, management: false).take(_barCount).toList();

  /// Everything not in the bottom bar (the "rest"), for the drawer.
  List<AppDestination> get _drawerDestinations {
    final barPaths = {for (final destination in _bar) destination.path};
    return [
      for (final destination in destinationsFor(widget.role))
        if (!barPaths.contains(destination.path)) destination,
    ];
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _navigate(String path) {
    _scaffoldKey.currentState?.closeDrawer();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final bar = _bar;
    final destinations = _drawerDestinations;
    final menuIndex = bar.length;
    final selected = bar.indexWhere((d) => d.matches(widget.location));
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppMenuDrawer(
        role: widget.role,
        location: widget.location,
        destinations: destinations,
        onNavigate: _navigate,
        onLogout: () {
          _scaffoldKey.currentState?.closeDrawer();
          context.read<AuthCubit>().logout();
        },
      ),
      body: widget.content,
      floatingActionButton: isManagementLocation(widget.location)
          ? null
          : const _ScanQrFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected >= 0 ? selected : menuIndex,
        onDestinationSelected: (index) {
          if (index == menuIndex) {
            _openDrawer();
            return;
          }
          context.go(bar[index].path);
        },
        destinations: [
          for (final destination in bar)
            NavigationDestination(
              icon: _NavIcon(destination: destination, icon: destination.icon),
              selectedIcon: _NavIcon(
                destination: destination,
                icon: destination.selectedIcon,
              ),
              label: destination.label(context.l10n),
            ),
          NavigationDestination(
            icon: const Icon(Icons.menu),
            label: context.l10n.navMenu,
            tooltip: context.l10n.navMenuTooltip,
          ),
        ],
      ),
    );
  }
}

/// Side menu for the phone layout: everything that does not fit in the five
/// bottom tabs (notifications, contact, management sections) plus the account.
class _AppMenuDrawer extends StatelessWidget {
  const _AppMenuDrawer({
    required this.role,
    required this.location,
    required this.destinations,
    required this.onNavigate,
    required this.onLogout,
  });

  final UserRole role;
  final String location;
  final List<AppDestination> destinations;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = switch (context.watch<AuthCubit>().state) {
      AuthAuthenticated(:final session) => session.user,
      _ => null,
    };
    final title = _lotTitle(context, l10n);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                Space.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_parking_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (user != null)
                          Text(
                            '${user.displayName} · '
                            '${user.role == UserRole.admin ? l10n.roleAdmin : l10n.roleOperator}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                children: [
                  for (final destination in destinations)
                    ListTile(
                      leading: Icon(destination.icon),
                      title: Text(destination.label(l10n)),
                      selected: destination.matches(location),
                      onTap: () => onNavigate(destination.path),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.actionLogout),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }

  String _lotTitle(BuildContext context, AppLocalizations l10n) {
    try {
      return context.select<BrandingCubit, String>(
        (cubit) => cubit.state.titleFor(l10n),
      );
    } on ProviderNotFoundException {
      return l10n.navHome;
    }
  }
}

/// Floating shortcut: photograph a receipt's QR and open that session's
/// check-out. Hidden when the platform has no camera capture/decoder.
class _ScanQrFab extends StatelessWidget {
  const _ScanQrFab();

  @override
  Widget build(BuildContext context) {
    final capture = serviceLocator.isRegistered<PlateImageCapture>()
        ? serviceLocator<PlateImageCapture>()
        : null;
    final decoder = serviceLocator.isRegistered<QrDecoder>()
        ? serviceLocator<QrDecoder>()
        : null;
    if (kIsWeb && (capture == null || decoder == null)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      tooltip: context.l10n.scanExitTooltip,
      onPressed: () => unawaited(_scan(context, capture, decoder)),
      child: const Icon(Icons.qr_code_scanner),
    );
  }

  Future<void> _scan(
    BuildContext context,
    PlateImageCapture? capture,
    QrDecoder? decoder,
  ) async {
    String? payload;
    try {
      if (!kIsWeb) {
        payload = await scanQrWithCamera(context);
      } else if (capture != null && decoder != null) {
        final file = await capture.capture();
        if (file != null) {
          payload = await decoder.decode(await file.readAsBytes());
        }
      }
    } catch (_) {
      payload = null;
    }
    if (!context.mounted) {
      return;
    }
    final plate = payload == null ? null : plateFromQrPayload(payload);
    if (plate == null) {
      if (payload != null) {
        showInfoSnack(context, context.l10n.checkOutQrUnreadable);
      }
      return;
    }
    context.go('/check-out?scan=$plate');
  }
}

/// Adds the unread badge to the notifications destination.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.destination, required this.icon});

  final AppDestination destination;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (destination.path != '/notifications') {
      return Icon(icon);
    }
    final unread = context.select<NotificationsCubit, int>(
      (cubit) => cubit.state.unreadCount,
    );
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: Icon(icon),
    );
  }
}
