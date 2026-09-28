import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'app_icon_button.dart';

/// Evidence thumbnail with a 48dp "Quitar foto" button (tooltip = name).
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.bytes,
    required this.index,
    required this.onRemove,
  });

  final Uint8List bytes;

  /// 1-based position, announced as "Foto N".
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (Layout.thumbnail * MediaQuery.devicePixelRatioOf(context))
        .round();
    return SizedBox.square(
      dimension: Layout.thumbnail,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              image: true,
              label: context.l10n.photoLabel(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: AppIconButton(
              icon: Icons.close,
              tooltip: context.l10n.removePhoto,
              onPressed: onRemove,
              variant: AppIconButtonVariant.filledTonal,
            ),
          ),
        ],
      ),
    );
  }
}
