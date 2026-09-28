import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

/// Footer of paginated lists: spinner while loading, else "Cargar más".
class LoadMoreTile extends StatelessWidget {
  const LoadMoreTile({super.key, required this.loading, required this.onLoad});

  final bool loading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.md),
    child: Center(
      child: loading
          ? CircularProgressIndicator(semanticsLabel: context.l10n.loading)
          : OutlinedButton(
              onPressed: onLoad,
              child: Text(context.l10n.actionLoadMore),
            ),
    ),
  );
}
