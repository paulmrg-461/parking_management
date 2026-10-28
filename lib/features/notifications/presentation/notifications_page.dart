import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../app/di/injection.dart';
import '../application/notifications_cubit.dart';
import '../application/web_push_service.dart';
import '../domain/entities/app_notification.dart';
import 'notification_routes.dart';

/// Inbox grouped by day (today / yesterday / earlier) with an unread filter,
/// a tonal icon per notification type and an empty state that points to the
/// records page. Tapping a row marks it read and deep-links by type.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.onOpenRecords});

  /// Test seam: receives the CTA tap instead of navigating with the router.
  final VoidCallback? onOpenRecords;

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.actionError != current.actionError &&
          current.actionError != null,
      listener: (context, state) {
        final failure = state.actionError;
        if (failure != null) {
          showErrorSnack(context, context.l10n.failure(failure));
          context.read<NotificationsCubit>().clearActionError();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.notificationsTitle),
          actions: [
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) => TextButton(
                onPressed: state.unreadCount == 0
                    ? null
                    : context.read<NotificationsCubit>().markAllRead,
                child: Text(context.l10n.notificationsMarkAll),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const WebPushToggle(),
            Expanded(
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) => switch (state.status) {
                  NotificationsStatus.initial ||
                  NotificationsStatus.loading => const SkeletonList(),
                  NotificationsStatus.failure => ErrorState(
                    message: state.error == null
                        ? context.l10n.errorUnknown
                        : context.l10n.failure(state.error!),
                    onRetry: context.read<NotificationsCubit>().load,
                  ),
                  NotificationsStatus.loaded => _Inbox(
                    state: state,
                    onOpenRecords:
                        onOpenRecords ?? () => context.go('/records'),
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

/// Browser-only push switch. Rendered only when the build carries a VAPID
/// public key and the runtime can subscribe; hidden everywhere else.
class WebPushToggle extends StatefulWidget {
  const WebPushToggle({super.key});

  @override
  State<WebPushToggle> createState() => _WebPushToggleState();
}

class _WebPushToggleState extends State<WebPushToggle> {
  WebPushService? _service;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!serviceLocator.isRegistered<WebPushService>()) {
      return;
    }
    final service = serviceLocator<WebPushService>();
    if (!service.supported) {
      return;
    }
    final enabled = await service.isEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _service = service;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool value) async {
    final service = _service;
    if (service == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    if (value) {
      final granted = await service.enable();
      if (mounted) {
        setState(() {
          _enabled = granted;
          _busy = false;
        });
        if (!granted) {
          showErrorSnack(context, context.l10n.webPushDenied);
        }
      }
      return;
    }
    await service.disable();
    if (mounted) {
      setState(() {
        _enabled = false;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          value: _enabled,
          onChanged: _busy ? null : _toggle,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(context.l10n.webPushTitle),
          subtitle: Text(context.l10n.webPushSubtitle),
        ),
      ),
    );
  }
}

class _Inbox extends StatefulWidget {
  const _Inbox({required this.state, required this.onOpenRecords});

  final NotificationsState state;
  final VoidCallback onOpenRecords;

  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  bool _unreadOnly = false;

  List<AppNotification> get _visible => _unreadOnly
      ? [
          for (final item in widget.state.items)
            if (!item.isRead) item,
        ]
      : widget.state.items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: context.read<NotificationsCubit>().load,
        child: EmptyState(
          icon: Icons.notifications_none,
          title: l10n.notificationsEmptyTitle,
          message: l10n.notificationsEmptyHint,
          action: FilledButton.tonalIcon(
            onPressed: widget.onOpenRecords,
            icon: const Icon(Icons.history),
            label: Text(l10n.notificationsOpenRecords),
          ),
        ),
      );
    }
    final visible = _visible;
    return RefreshIndicator(
      onRefresh: context.read<NotificationsCubit>().load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.sm,
          Space.md,
          Space.xl,
        ),
        children: [
          _FilterRow(
            unreadOnly: _unreadOnly,
            unreadCount: widget.state.unreadCount,
            onChanged: (value) => setState(() => _unreadOnly = value),
          ),
          const SizedBox(height: Space.md),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: l10n.notificationsUnreadOnly,
                message: l10n.notificationsUnreadEmpty,
              ),
            )
          else
            ..._grouped(context, visible),
        ],
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, List<AppNotification> items) {
    final groups = _NotificationGroup.from(items);
    return [
      for (final group in groups) ...[
        SectionHeader(
          icon: group.icon,
          title: group.label(context),
          action: Text(
            '${group.items.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: Space.sm),
        for (final notification in group.items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: _NotificationTile(notification: notification),
          ),
        const SizedBox(height: Space.md),
      ],
    ];
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onChanged,
  });

  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.notificationsFilterLabel,
      container: true,
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          ChoiceChip(
            selected: !unreadOnly,
            showCheckmark: false,
            label: Text(l10n.notificationsAll),
            onSelected: (_) => onChanged(false),
          ),
          ChoiceChip(
            selected: unreadOnly,
            showCheckmark: false,
            avatar: unreadCount == 0
                ? null
                : CircleAvatar(
                    radius: 9,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      '$unreadCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            label: Text(l10n.notificationsUnreadOnly),
            onSelected: (_) => onChanged(true),
          ),
        ],
      ),
    );
  }
}

/// A day bucket: today, yesterday or everything older.
class _NotificationGroup {
  const _NotificationGroup(this.icon, this.label, this.items);

  final IconData icon;
  final String Function(BuildContext) label;
  final List<AppNotification> items;

  static List<_NotificationGroup> from(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final buckets = <String, List<AppNotification>>{
      'today': [],
      'yesterday': [],
      'earlier': [],
    };
    for (final item in items) {
      final local = item.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final key = day == today
          ? 'today'
          : day == yesterday
          ? 'yesterday'
          : 'earlier';
      buckets[key]!.add(item);
    }
    return [
      if (buckets['today']!.isNotEmpty)
        _NotificationGroup(
          Icons.today_outlined,
          (context) => context.l10n.notificationsToday,
          buckets['today']!,
        ),
      if (buckets['yesterday']!.isNotEmpty)
        _NotificationGroup(
          Icons.history_toggle_off,
          (context) => context.l10n.notificationsYesterday,
          buckets['yesterday']!,
        ),
      if (buckets['earlier']!.isNotEmpty)
        _NotificationGroup(
          Icons.calendar_month_outlined,
          (context) => context.l10n.notificationsEarlier,
          buckets['earlier']!,
        ),
    ];
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: unread ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(context, unread),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: unread
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          child: Icon(
            _iconFor(notification.type),
            size: Space.md,
            color: unread ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(notification.body),
            const SizedBox(height: Space.xs),
            Text(
              Formatters.dateTime(notification.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: unread
            ? Icon(Icons.circle, size: Space.sm, color: scheme.primary)
            : null,
      ),
    );
  }

  void _open(BuildContext context, bool unread) {
    if (unread) {
      context.read<NotificationsCubit>().markRead(notification.id);
    }
    final route = routeForNotification(notification);
    if (route != null) {
      context.go(route);
    }
  }

  static IconData _iconFor(String type) => switch (type) {
    'check_in' => Icons.login,
    'check_out' => Icons.logout,
    'monthly_pass_expiring' => Icons.card_membership,
    'monthly_pass_renewed' => Icons.autorenew,
    'overstay' => Icons.timer_outlined,
    'shift_closed' => Icons.point_of_sale,
    _ => Icons.notifications,
  };
}
