import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../app/di/injection.dart';
import '../application/web_push_service.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/notifications_cubit.dart';
import '../domain/entities/app_notification.dart';
import 'notification_routes.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
            NotificationsStatus.loading => const Center(
              child: SkeletonList(),
            ),
            NotificationsStatus.failure => ErrorState(
              message: state.error == null
                  ? context.l10n.errorUnknown
                  : context.l10n.failure(state.error!),
              onRetry: context.read<NotificationsCubit>().load,
            ),
            NotificationsStatus.loaded => _Inbox(state: state),
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
    return SwitchListTile(
      value: _enabled,
      onChanged: _busy ? null : _toggle,
      secondary: const Icon(Icons.notifications_active_outlined),
      title: Text(context.l10n.webPushTitle),
      subtitle: Text(context.l10n.webPushSubtitle),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: context.read<NotificationsCubit>().load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height / 4),
            Icon(
              Icons.notifications_none,
              size: Space.xxl,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: Space.md),
            Center(child: Text(context.l10n.notificationsEmpty)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: context.read<NotificationsCubit>().load,
      child: ListView.separated(
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) =>
            _NotificationTile(notification: state.items[index]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => _open(context, unread),
      leading: CircleAvatar(
        backgroundColor: unread
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(_iconFor(notification.type), size: Space.md),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: Space.xs),
          Text(
            Formatters.dateTime(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: unread
          ? Icon(Icons.circle, size: Space.sm, color: scheme.primary)
          : null,
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
