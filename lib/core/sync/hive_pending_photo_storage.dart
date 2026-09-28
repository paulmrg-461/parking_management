import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:hive_ce/hive_ce.dart';

import '../error/failure.dart';
import 'pending_photo_storage.dart';

/// Web [PendingPhotoStorage]: photo bytes live in a Hive box (IndexedDB on
/// web) keyed `<clientRef>/photo_<i>.<ext>`; the keys are the references.
class HivePendingPhotoStorage implements PendingPhotoStorage {
  static const _boxName = 'pending_photos';

  Future<Box<Uint8List>> _box() => Hive.openBox<Uint8List>(_boxName);

  @override
  Future<List<String>> persist({
    required String clientRef,
    required List<XFile> photos,
  }) async {
    final box = await _box();
    final refs = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final ref = '$clientRef/photo_$i${photoExtensionOf(photos[i])}';
      await box.put(ref, await photos[i].readAsBytes());
      refs.add(ref);
    }
    return refs;
  }

  @override
  Future<List<XFile>> load(List<String> refs) async {
    final box = await _box();
    return [for (final ref in refs) _fileFor(ref, box.get(ref))];
  }

  @override
  Future<void> deleteFor(String clientRef) async {
    final box = await _box();
    final prefix = '$clientRef/';
    final keys = box.keys.whereType<String>().where(
      (k) => k.startsWith(prefix),
    );
    await box.deleteAll(keys.toList());
  }

  XFile _fileFor(String ref, Uint8List? bytes) {
    if (bytes == null) {
      throw const StorageFailure(
        'Queued evidence photo is missing',
        ClientFailureCodes.missingPendingPhoto,
      );
    }
    final name = ref.split('/').last;
    // `path` too: on mobile `XFile.name` derives from the path only.
    return XFile.fromData(
      bytes,
      name: name,
      path: name,
      mimeType: photoMimeType(ref),
    );
  }
}
