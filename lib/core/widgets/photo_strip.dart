import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'photo_thumb.dart';

/// Evidence photos: thumbnails, an add tile (disabled at [max]) and the
/// limit notice.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.max,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Uint8List> photos;
  final int max;

  /// `null` disables the add tile (e.g. while submitting).
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  bool get _full => photos.length >= max;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.photosTitle(photos.length, max),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (var i = 0; i < photos.length; i++)
              PhotoThumb(
                bytes: photos[i],
                index: i + 1,
                onRemove: () => onRemove(i),
              ),
            _AddPhotoTile(onPressed: _full ? null : onAdd),
          ],
        ),
        if (_full)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              l10n.photosMaxReached(max),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.addPhoto;
    return SizedBox.square(
      dimension: Layout.thumbnail,
      child: Tooltip(
        message: label,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(Layout.thumbnail),
          ),
          child: Icon(Icons.add_a_photo_outlined, semanticLabel: label),
        ),
      ),
    );
  }
}
