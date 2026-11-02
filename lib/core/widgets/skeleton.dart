import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

/// A rounded placeholder block. The pulse is driven by [_SkeletonPulse]'s
/// single controller so a screen never runs one animation per row.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Radii.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shared pulse + "loading" semantics. Honors the platform "reduce motion"
/// setting by rendering a static skeleton.
class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({required this.child});

  final Widget child;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.short,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      container: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Row-shaped placeholder for lists with a leading avatar and two text lines.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) => _SkeletonPulse(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Space.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (_, _) => const _SkeletonTile(),
    ),
  );
}

/// Card-shaped placeholder for dashboards, panels and detail pages: it mirrors
/// the real card geometry (title, two lines and a footer) to avoid layout
/// shifts when the data arrives.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) => _SkeletonPulse(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Space.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (_, _) => const _SkeletonCard(),
    ),
  );
}

/// Dense row placeholder for tables (audit, records, diagnostics).
class SkeletonTable extends StatelessWidget {
  const SkeletonTable({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) => _SkeletonPulse(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Space.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            SkeletonBox(width: 28, height: 28, radius: Radii.pill),
            SizedBox(width: Space.md),
            Expanded(child: SkeletonBox(height: 12)),
            SizedBox(width: Space.lg),
            SkeletonBox(width: 56, height: 12),
          ],
        ),
      ),
    ),
  );
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 44, height: 44, radius: Radii.pill),
        SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140),
              SizedBox(height: Space.sm),
              SkeletonBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: Space.md),
          SkeletonBox(height: 28),
          SizedBox(height: Space.sm),
          SkeletonBox(width: 220, height: 12),
          SizedBox(height: Space.md),
          SkeletonBox(width: 96, height: 24, radius: Radii.pill),
        ],
      ),
    );
  }
}
