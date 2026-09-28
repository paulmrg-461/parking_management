import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'empty_state.dart';
import 'error_state.dart';

/// What a data screen can be showing. Pages map their cubit state to this.
sealed class AsyncStatus<T> {
  const AsyncStatus();
}

final class AsyncLoading<T> extends AsyncStatus<T> {
  const AsyncLoading();
}

final class AsyncEmpty<T> extends AsyncStatus<T> {
  const AsyncEmpty(this.message, {this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;
}

final class AsyncFailed<T> extends AsyncStatus<T> {
  const AsyncFailed(this.message, this.retry);

  final String message;
  final VoidCallback retry;
}

final class AsyncReady<T> extends AsyncStatus<T> {
  const AsyncReady(this.data);

  final T data;
}

/// Loading / empty / error+retry / data, cross-faded on state changes.
/// Data → data updates keep the same key, so lists are not re-animated.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.status, required this.builder});

  final AsyncStatus<T> status;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.short,
    child: KeyedSubtree(
      key: ValueKey(status.runtimeType),
      child: switch (status) {
        AsyncLoading() => Center(
          child: CircularProgressIndicator(semanticsLabel: context.l10n.loading),
        ),
        AsyncEmpty(:final message, :final icon) => EmptyState(
          message: message,
          icon: icon,
        ),
        AsyncFailed(:final message, :final retry) => ErrorState(
          message: message,
          onRetry: retry,
        ),
        AsyncReady(:final data) => builder(data),
      },
    ),
  );
}
