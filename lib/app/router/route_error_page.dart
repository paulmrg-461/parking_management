import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/empty_state.dart';
import 'route_access.dart';

/// Friendly fallback for unknown or broken routes (deep links from QR codes,
/// old bookmarks, renamed sections). Keeps the operator one tap from home
/// instead of showing a raw router exception.
class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeErrorTitle)),
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: l10n.routeErrorTitle,
        message: l10n.routeErrorBody,
        action: FilledButton.icon(
          onPressed: () => context.go(homePath),
          icon: const Icon(Icons.home_outlined),
          label: Text(l10n.routeErrorHome),
        ),
      ),
    );
  }
}
