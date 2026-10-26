import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/core/storage/session_cache_cleaner.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_cache_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Success: logout drops every cached reference-data box', () async {
    for (final name in SessionCacheCleaner.cacheBoxNames) {
      final box = await Hive.openBox<String>(name);
      await box.put('k', 'v');
    }

    await const SessionCacheCleaner().clear();

    for (final name in SessionCacheCleaner.cacheBoxNames) {
      expect(Hive.isBoxOpen(name), isFalse, reason: name);
      final reopened = await Hive.openBox<String>(name);
      expect(reopened, isEmpty, reason: name);
    }
  });

  test('Security: the auth session box is not touched by the cache cleaner', () async {
    final auth = await Hive.openBox<String>('auth');
    await auth.put('session', 'still-here');

    await const SessionCacheCleaner().clear();

    expect(Hive.box<String>('auth').get('session'), 'still-here');
  });
}
