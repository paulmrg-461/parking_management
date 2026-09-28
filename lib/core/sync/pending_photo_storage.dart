import 'package:cross_file/cross_file.dart';

/// Persists a queued check-in's evidence photos until the outbox replays it.
///
/// The picker's original file lives in a transient/cache location the OS
/// can reclaim (mobile) or only in memory (web), so a durable copy is
/// required for a queued check-in to survive until replay. Implementations:
/// files on mobile, Hive bytes on web.
abstract class PendingPhotoStorage {
  /// Stores [photos] for [clientRef] and returns opaque references, in the
  /// same order, to be queued in the mutation payload.
  Future<List<String>> persist({
    required String clientRef,
    required List<XFile> photos,
  });

  /// Resolves references returned by [persist] back into readable photos.
  Future<List<XFile>> load(List<String> refs);

  /// Deletes every photo stored for [clientRef] (no-op if none).
  Future<void> deleteFor(String clientRef);
}

/// MIME type for a photo file name (backend accepts JPEG/PNG only).
String photoMimeType(String name) =>
    name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

/// File extension (with dot) for [photo], defaulting to `.jpg`. Looks at
/// the MIME type, then the name (web), then the path (mobile).
String photoExtensionOf(XFile photo) {
  final label = photo.name.isNotEmpty ? photo.name : photo.path;
  final isPng =
      photo.mimeType == 'image/png' || label.toLowerCase().endsWith('.png');
  return isPng ? '.png' : '.jpg';
}
