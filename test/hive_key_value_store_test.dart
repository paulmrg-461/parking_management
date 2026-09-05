import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/storage/hive_key_value_store.dart';

void main() {
  late Directory tempDir;
  late HiveKeyValueStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('parking_store_test');
    store = HiveKeyValueStore(pathProvider: () async => tempDir.path);
  });

  tearDown(() async {
    await store.close();
    await tempDir.delete(recursive: true);
  });

  group('HiveKeyValueStore', () {
    test('stores and retrieves a value', () async {
      await store.init();

      await store.put('settings', 'deviceId', 'abc-123');

      expect(store.get('settings', 'deviceId'), 'abc-123');
    });

    test('returns null for a missing key', () async {
      await store.init();
      await store.put('settings', 'existing', 'value');

      expect(store.get('settings', 'missing'), isNull);
    });

    test('keeps values isolated between boxes', () async {
      await store.init();

      await store.put('boxA', 'key', 'valueA');
      await store.put('boxB', 'key', 'valueB');

      expect(store.get('boxA', 'key'), 'valueA');
      expect(store.get('boxB', 'key'), 'valueB');
    });
  });
}
