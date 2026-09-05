import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import 'key_value_store.dart';

class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore({this.pathProvider});

  final Future<String> Function()? pathProvider;

  bool _initialized = false;

  Future<String> _resolvePath() async {
    final provider = pathProvider;
    if (provider != null) {
      return provider();
    }
    if (kIsWeb) {
      return '';
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    Hive.init(await _resolvePath());
    _initialized = true;
  }

  @override
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }

  @override
  Future<void> put(String box, String key, Object? value) async {
    final opened = await Hive.openBox<Object?>(box);
    await opened.put(key, value);
  }

  @override
  Object? get(String box, String key) {
    if (!Hive.isBoxOpen(box)) {
      return null;
    }
    return Hive.box<Object?>(box).get(key);
  }

  @override
  Future<void> remove(String box, String key) async {
    final opened = await Hive.openBox<Object?>(box);
    await opened.delete(key);
  }
}
