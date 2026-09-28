import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Square spacer on the 8pt grid; works in both rows and columns.
class AppGap extends StatelessWidget {
  const AppGap(this.size, {super.key});

  const AppGap.xs({super.key}) : size = Space.xs;
  const AppGap.sm({super.key}) : size = Space.sm;
  const AppGap.md({super.key}) : size = Space.md;
  const AppGap.lg({super.key}) : size = Space.lg;
  const AppGap.xl({super.key}) : size = Space.xl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
