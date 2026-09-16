import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Persists a queued check-in's evidence photos into app-persistent storage
/// (`getApplicationSupportDirectory()/pending_check_ins/<clientRef>/`).
///
/// The image picker's original file lives in a transient/cache location the
/// OS can reclaim before the offline queue drains, so this copy is required
/// (not merely a convenience) for a queued check-in to survive until replay.
class PendingPhotoStorage {
  static const _rootFolder = 'pending_check_ins';

  /// Copies each of [photos] into the persistent folder for [clientRef] and
  /// returns the persisted file paths, in the same order as [photos].
  Future<List<String>> persist({
    required String clientRef,
    required List<File> photos,
  }) async {
    final dir = await _directoryFor(clientRef);
    await dir.create(recursive: true);

    final persistedPaths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      persistedPaths.add(await _copyOne(photos[i], dir, i));
    }
    return persistedPaths;
  }

  /// Deletes the persisted photo folder for [clientRef] (cleanup after a
  /// successful replay). No-op if it does not exist.
  Future<void> deleteFor(String clientRef) async {
    final dir = await _directoryFor(clientRef);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> _copyOne(File source, Directory dir, int index) async {
    final extension = path.extension(source.path);
    final target = path.join(dir.path, 'photo_$index$extension');
    final copied = await source.copy(target);
    return copied.path;
  }

  Future<Directory> _directoryFor(String clientRef) async {
    final base = await getApplicationSupportDirectory();
    return Directory(path.join(base.path, _rootFolder, clientRef));
  }
}
