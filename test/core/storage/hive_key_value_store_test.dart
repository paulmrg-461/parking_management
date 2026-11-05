import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/core/storage/hive_key_value_store.dart';

void main() {
  test('Security: preferences survive an app restart', () async {
    final dir = await Directory.systemTemp.createTemp('parking-prefs-');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    final first = HiveKeyValueStore(pathProvider: () async => dir.path);
    await first.init();
    await first.put('preferences', 'auto_lock_minutes', 15);
    await first.close();

    // A cold start creates a new store: `get` must see the value before any
    // `put` opens the box.
    final second = HiveKeyValueStore(pathProvider: () async => dir.path);
    await second.init();
    expect(second.get('preferences', 'auto_lock_minutes'), 15);
    await second.close();
  });
}
