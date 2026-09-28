import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/sync/file_pending_photo_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points `getApplicationSupportDirectory()` at a temp folder for the
/// duration of a test, so [FilePendingPhotoStorage] can be tested hermetically
/// without touching the real host filesystem's app-support location.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._supportPath);

  final String _supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;
}

void main() {
  late Directory supportDir;
  late Directory sourceDir;

  setUp(() async {
    supportDir = await Directory.systemTemp.createTemp(
      'pending_photo_storage_support',
    );
    sourceDir = await Directory.systemTemp.createTemp(
      'pending_photo_storage_source',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);
  });

  tearDown(() async {
    await supportDir.delete(recursive: true);
    await sourceDir.delete(recursive: true);
  });

  XFile writeSourcePhoto(String name, String content) {
    final file = File(path.join(sourceDir.path, name));
    file.writeAsStringSync(content);
    return XFile(file.path);
  }

  test(
    'Success: persist copies photo bytes and returns the persisted paths',
    () async {
      final storage = FilePendingPhotoStorage();
      final photo = writeSourcePhoto('a.jpg', 'photo-bytes-a');

      final persistedPaths = await storage.persist(
        clientRef: 'ref-1',
        photos: [photo],
      );

      expect(persistedPaths, hasLength(1));
      expect(File(persistedPaths.single).existsSync(), isTrue);
      expect(File(persistedPaths.single).readAsStringSync(), 'photo-bytes-a');
      expect(persistedPaths.single, contains('pending_check_ins'));
      expect(persistedPaths.single, contains('ref-1'));
    },
  );

  test(
    'Failure: deleteFor removes exactly that clientRef\'s files and no others',
    () async {
      final storage = FilePendingPhotoStorage();
      final photoA = writeSourcePhoto('a.jpg', 'a');
      final photoB = writeSourcePhoto('b.jpg', 'b');

      final pathsA = await storage.persist(
        clientRef: 'ref-a',
        photos: [photoA],
      );
      final pathsB = await storage.persist(
        clientRef: 'ref-b',
        photos: [photoB],
      );

      await storage.deleteFor('ref-a');

      expect(File(pathsA.single).existsSync(), isFalse);
      expect(File(pathsB.single).existsSync(), isTrue);
    },
  );

  test('Security/robustness: persisted bytes survive deletion of the original source file', () async {
    final storage = FilePendingPhotoStorage();
    final photo = writeSourcePhoto('c.jpg', jsonEncode({'evidence': 'dent'}));

    final persistedPaths = await storage.persist(
      clientRef: 'ref-c',
      photos: [photo],
    );
    await File(photo.path).delete();

    expect(File(photo.path).existsSync(), isFalse);
    expect(File(persistedPaths.single).existsSync(), isTrue);
    expect(
      File(persistedPaths.single).readAsStringSync(),
      jsonEncode({'evidence': 'dent'}),
    );
  });

  test(
    'Success: load returns the persisted photos readable as bytes',
    () async {
      final storage = FilePendingPhotoStorage();
      final refs = await storage.persist(
        clientRef: 'ref-d',
        photos: [writeSourcePhoto('d.png', 'png-bytes')],
      );

      final loaded = await storage.load(refs);

      expect(loaded.single.name, endsWith('.png'));
      expect(utf8.decode(await loaded.single.readAsBytes()), 'png-bytes');
    },
  );
}
