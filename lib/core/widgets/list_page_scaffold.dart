import 'package:flutter/material.dart';

import 'sync_badge.dart';

/// Template for admin CRUD lists: title, SyncBadge, an "add" FAB with an
/// accessible tooltip, and pull-to-refresh around [body].
class ListPageScaffold extends StatelessWidget {
  const ListPageScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onRefresh,
    this.onAdd,
    this.addTooltip,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAdd;
  final String? addTooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: [...actions, const SyncBadge()]),
    floatingActionButton: onAdd == null
        ? null
        : FloatingActionButton(
            tooltip: addTooltip,
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
    body: RefreshIndicator(onRefresh: onRefresh, child: body),
  );
}
