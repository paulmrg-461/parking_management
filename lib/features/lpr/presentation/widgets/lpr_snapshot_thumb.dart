import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/skeleton.dart';

/// A small snapshot for a pending read. The image is private evidence: the
/// membership-based Storage policy decides whether the bytes arrive, so an
/// error simply shows the "no image" placeholder.
class LprSnapshotThumb extends StatefulWidget {
  const LprSnapshotThumb({
    super.key,
    required this.path,
    required this.loader,
    this.width = 112,
    this.height = 76,
  });

  final String path;
  final Future<Uint8List> Function(String path) loader;
  final double width;
  final double height;

  @override
  State<LprSnapshotThumb> createState() => _LprSnapshotThumbState();
}

class _LprSnapshotThumbState extends State<LprSnapshotThumb> {
  late final Future<Uint8List> _future = widget.loader(widget.path);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<Uint8List>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonBox(height: 76, width: 112);
            }
            final bytes = snapshot.data;
            if (snapshot.hasError || bytes == null || bytes.isEmpty) {
              return const _Missing();
            }
            return Image.memory(
              bytes,
              key: const Key('lpr_snapshot_image'),
              width: widget.width,
              height: widget.height,
              fit: BoxFit.cover,
              cacheWidth: 224,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      key: const Key('lpr_snapshot_missing'),
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: Space.md, color: scheme.onSurfaceVariant),
          const SizedBox(height: Space.xs),
          Text(
            context.l10n.gateSnapshotMissing,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
