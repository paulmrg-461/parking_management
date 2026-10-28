import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/notifications_cubit.dart';

/// Runs [onActivity] when another device's check-in/check-out arrives through
/// Realtime, so a page showing that data refetches instead of staying stale.
/// Silent when the page has no notifications cubit (isolated tests).
class RealtimeActivityListener extends StatelessWidget {
  const RealtimeActivityListener({
    super.key,
    required this.onActivity,
    required this.child,
  });

  final VoidCallback onActivity;
  final Widget child;

  static bool _hasCubit(BuildContext context) {
    try {
      context.read<NotificationsCubit>();
      return true;
    } on ProviderNotFoundException {
      return false;
    }
  }

  static bool _isActivity(NotificationsState state) =>
      switch (state.latestArrived?.data['action']) {
        'check_in' || 'check_out' => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    if (!_hasCubit(context)) {
      return child;
    }
    return BlocListener<NotificationsCubit, NotificationsState>(
      listenWhen: (previous, current) =>
          previous.latestArrived?.id != current.latestArrived?.id &&
          _isActivity(current),
      listener: (_, _) => onActivity(),
      child: child,
    );
  }
}
