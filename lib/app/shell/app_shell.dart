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
      listener: (context, state) => _reloadForLot(context),
      child: BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.latestArrived?.id != current.latestArrived?.id,
      listener: (context, state) {
        final notification = state.latestArrived;
        if (notification == null || _isOwnEcho(notification)) {
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
void _reloadForLot(BuildContext context) {
  try {
    unawaited(context.read<DashboardCubit>().load());
  } on ProviderNotFoundException {
    // no dashboard in this context
  }
  try {
    unawaited(context.read<ShiftCubit>().load());
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
      floatingActionButton: const _ScanQrFab(),
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
      floatingActionButton: const _ScanQrFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(primary, more),
        onDestinationSelected: (i) => i < primary.length
            ? context.go(primary[i].path)
            : _showMore(context, more),
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: _NavIcon(destination: d, icon: d.icon),
              selectedIcon: _NavIcon(
                destination: d,
                icon: d.selectedIcon,
              ),
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
