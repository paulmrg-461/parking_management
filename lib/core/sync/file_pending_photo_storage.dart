import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'pending_photo_storage.dart';

/// Mobile [PendingPhotoStorage]: copies photos into
/// `getApplicationSupportDirectory()/pending_check_ins/<clientRef>/` and
/// uses the absolute file paths as references.
class FilePendingPhotoStorage implements PendingPhotoStorage {
  static const _rootFolder = 'pending_check_ins';

  @override
  Future<List<String>> persist({
    required String clientRef,
    required List<XFile> photos,
  }) async {
    final dir = await _directoryFor(clientRef);
    await dir.create(recursive: true);
    return [
      for (var i = 0; i < photos.length; i++) await _copyOne(photos[i], dir, i),
    ];
  }

  @override
  Future<List<XFile>> load(List<String> refs) async => [
    for (final ref in refs) XFile(ref, mimeType: photoMimeType(ref)),
  ];

  @override
  Future<void> deleteFor(String clientRef) async {
    final dir = await _directoryFor(clientRef);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> _copyOne(XFile source, Directory dir, int index) async {
    final extension = photoExtensionOf(source);
    final target = path.join(dir.path, 'photo_$index$extension');
    await source.saveTo(target);
    return target;
  }

  Future<Directory> _directoryFor(String clientRef) async {
    final base = await getApplicationSupportDirectory();
    return Directory(path.join(base.path, _rootFolder, clientRef));
  }
}
