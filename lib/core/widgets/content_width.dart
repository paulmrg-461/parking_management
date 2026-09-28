import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Centers [child] and caps its width ([Layout.maxForm] by default) so
/// forms stay readable on web/tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = Layout.maxForm,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
