import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/hive_pending_photo_storage.dart';

XFile _photo(String name, String content) => XFile.fromData(
  Uint8List.fromList(utf8.encode(content)),
  name: name,
  path: name,
);

void main() {
  late Directory dir;
  late HivePendingPhotoStorage storage;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_photos');
    Hive.init(dir.path);
    storage = HivePendingPhotoStorage();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'Success: persisted bytes survive a restart and load back in order',
    () async {
      final refs = await storage.persist(
        clientRef: 'ref-1',
        photos: [_photo('a.jpg', 'A'), _photo('b.png', 'B')],
      );
      await Hive.close();

      final loaded = await HivePendingPhotoStorage().load(refs);

      expect(
        [for (final f in loaded) utf8.decode(await f.readAsBytes())],
        ['A', 'B'],
      );
      expect(loaded.last.name, endsWith('.png'));
      expect(loaded.last.mimeType, 'image/png');
    },
  );

  test(
    'Failure: loading a ref that no longer exists throws StorageFailure',
    () async {
      expect(
        () => storage.load(['ref-x/photo_0.jpg']),
        throwsA(isA<StorageFailure>()),
      );
    },
  );

  test('Security: deleteFor removes only that clientRef\'s photos', () async {
    final refsA = await storage.persist(
      clientRef: 'ref-a',
      photos: [_photo('a.jpg', 'A')],
    );
    final refsB = await storage.persist(
      clientRef: 'ref-ab',
      photos: [_photo('b.jpg', 'B')],
    );

    await storage.deleteFor('ref-a');

    expect(() => storage.load(refsA), throwsA(isA<StorageFailure>()));
    expect(await storage.load(refsB), hasLength(1));
  });
}
