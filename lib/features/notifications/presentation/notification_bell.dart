import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../application/notifications_cubit.dart';

/// AppBar bell with the unread count; opens the inbox.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = _maybeCubit(context);
    if (cubit == null) {
      // Isolated widget tests may not provide the global inbox.
      return const SizedBox.shrink();
    }
    final unread = context.select<NotificationsCubit, int>(
      (cubit) => cubit.state.unreadCount,
    );
    return IconButton(
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  NotificationsCubit? _maybeCubit(BuildContext context) {
    try {
      return context.read<NotificationsCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
