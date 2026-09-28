import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centers [children] but stays scrollable (pull-to-refresh on empty/error).
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight
              ? (constraints.maxHeight - Space.xxl).clamp(0, double.infinity)
              : 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    ),
  );
}
