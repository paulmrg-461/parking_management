import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fades and slides a list row in when it appears. Give it a stable key (the
/// row id) so state changes reuse it and the animation only runs once per
/// item; honour the platform "reduce motion" setting.
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({super.key, required this.child, this.index = 0});

  final Widget child;

  /// Position in the visible page; the first rows animate with a small delay
  /// so the list settles instead of flashing all at once.
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final delay = Duration(milliseconds: (index.clamp(0, 6) * 30));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.short + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
